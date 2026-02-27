"""
Archive Overview Dashboard Page
Comprehensive view of archive data with filterable time series, breakdowns, and top lists
"""

import pandas as pd
import streamlit as st
from utils.bigquery_utils import (
    get_bigquery_client,
    get_table_path,
    run_query,
)
from utils.chart_utils import create_bar_chart, create_line_chart

st.set_page_config(page_title="Archive Overview", page_icon="📰", layout="wide")

st.title("📰 Archive Overview")
st.markdown("*Comprehensive analysis of NYT archive data*")

client = get_bigquery_client()

if client is None:
    st.error("Unable to connect to BigQuery. Please check your credentials.")
    st.stop()

# Initialize session state for filters
if "archive_filters_applied" not in st.session_state:
    st.session_state.archive_filters_applied = False

# Sidebar filters
with st.sidebar:
    st.header("Filters")

    # Get min/max dates for the date range filter
    date_range_query = f"""
    SELECT
        MIN(pub_date) as min_date,
        MAX(pub_date) as max_date
    FROM {get_table_path('core', 'fct_articles')}
    WHERE pub_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 100 YEAR)
    """
    date_range_df = run_query(client, date_range_query)

    if not date_range_df.empty:
        min_date = pd.to_datetime(date_range_df["min_date"].iloc[0])
        max_date = pd.to_datetime(date_range_df["max_date"].iloc[0])

        # Date range filter
        st.subheader("Date Range")
        date_from = st.date_input(
            "From", value=min_date, min_value=min_date, max_value=max_date, key="date_from"
        )
        date_to = st.date_input(
            "To", value=max_date, min_value=min_date, max_value=max_date, key="date_to"
        )

        # Get filter options
        sections_query = f"""
        SELECT DISTINCT section_name
        FROM {get_table_path('core', 'fct_articles')}
        WHERE section_name != 'Unknown'
        ORDER BY section_name
        """
        sections_df = run_query(client, sections_query)
        sections_list = sections_df["section_name"].tolist() if not sections_df.empty else []

        news_desk_query = f"""
        SELECT DISTINCT news_desk
        FROM {get_table_path('core', 'fct_articles')}
        WHERE news_desk != 'Unknown'
        ORDER BY news_desk
        """
        news_desk_df = run_query(client, news_desk_query)
        news_desk_list = news_desk_df["news_desk"].tolist() if not news_desk_df.empty else []

        type_material_query = f"""
        SELECT DISTINCT type_of_material
        FROM {get_table_path('core', 'fct_articles')}
        WHERE type_of_material != 'Unknown'
        ORDER BY type_of_material
        """
        type_material_df = run_query(client, type_material_query)
        type_material_list = (
            type_material_df["type_of_material"].tolist() if not type_material_df.empty else []
        )

        # Section filter
        st.subheader("Sections")
        selected_sections = st.multiselect(
            "Select sections", options=sections_list, default=[], key="sections_filter"
        )

        # News Desk filter
        st.subheader("News Desk")
        selected_news_desks = st.multiselect(
            "Select news desks", options=news_desk_list, default=[], key="news_desk_filter"
        )

        # Type of Material filter
        st.subheader("Type of Material")
        selected_materials = st.multiselect(
            "Select material types",
            options=type_material_list,
            default=[],
            key="material_filter",
        )

        # Authors filter - load top authors for better UX
        authors_query = f"""
        SELECT author_full_name, total_articles
        FROM {get_table_path('analytics', 'agg_author_performance')}
        WHERE author_full_name IS NOT NULL AND author_full_name != ''
        ORDER BY total_articles DESC
        LIMIT 500
        """
        authors_df = run_query(client, authors_query)
        authors_list = authors_df["author_full_name"].tolist() if not authors_df.empty else []

        st.subheader("Authors")
        selected_authors = st.multiselect(
            "Select authors", options=authors_list, default=[], key="authors_filter"
        )

        # Keywords filter - load top keywords
        keywords_query = f"""
        SELECT keyword_value, SUM(article_count) as total
        FROM {get_table_path('analytics', 'agg_keyword_trends')}
        WHERE keyword_value IS NOT NULL
        GROUP BY keyword_value
        ORDER BY total DESC
        LIMIT 500
        """
        keywords_df = run_query(client, keywords_query)
        keywords_list = keywords_df["keyword_value"].tolist() if not keywords_df.empty else []

        st.subheader("Keywords")
        selected_keywords = st.multiselect(
            "Select keywords", options=keywords_list, default=[], key="keywords_filter"
        )

        st.markdown("---")

        if st.button("Apply Filters", type="primary"):
            st.session_state.archive_filters_applied = True
            st.rerun()

        if st.button("Reset Filters"):
            st.session_state.archive_filters_applied = False
            for key in [
                "sections_filter",
                "news_desk_filter",
                "material_filter",
                "authors_filter",
                "keywords_filter",
            ]:
                if key in st.session_state:
                    st.session_state[key] = []
            st.rerun()


# Build WHERE clause based on filters
def build_where_clause():
    conditions = ["pub_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 100 YEAR)"]

    if date_from and date_to:
        conditions.append(f"pub_date BETWEEN '{date_from}' AND '{date_to}'")

    if selected_sections:
        sections_str = "', '".join(selected_sections)
        conditions.append(f"section_name IN ('{sections_str}')")

    if selected_news_desks:
        desks_str = "', '".join(selected_news_desks)
        conditions.append(f"news_desk IN ('{desks_str}')")

    if selected_materials:
        materials_str = "', '".join(selected_materials)
        conditions.append(f"type_of_material IN ('{materials_str}')")

    return " AND ".join(conditions)


def build_author_filter():
    if selected_authors:
        authors_str = "', '".join([a.replace("'", "\\'") for a in selected_authors])
        return f"""
        AND a.article_id IN (
            SELECT DISTINCT article_id
            FROM {get_table_path('staging', 'stg_archive_articles')},
            UNNEST(byline_person) as author
            WHERE TRIM(CONCAT(
                COALESCE(author.firstname, ''),
                ' ',
                COALESCE(author.middlename, ''),
                ' ',
                COALESCE(author.lastname, '')
            )) IN ('{authors_str}')
        )
        """
    return ""


def build_keyword_filter():
    if selected_keywords:
        keywords_str = "', '".join([k.replace("'", "\\'") for k in selected_keywords])
        return f"""
        AND a.article_id IN (
            SELECT DISTINCT article_id
            FROM {get_table_path('staging', 'stg_archive_articles')},
            UNNEST(keywords) as keyword
            WHERE keyword.value IN ('{keywords_str}')
        )
        """
    return ""


where_clause = build_where_clause()
author_filter = build_author_filter()
keyword_filter = build_keyword_filter()

# Main content
st.markdown("---")

# Time Series: Articles Published Each Month
st.subheader("📈 Articles Published by Month")

with st.spinner("Loading monthly article counts..."):
    monthly_query = f"""
    SELECT
        DATE_TRUNC(pub_date, MONTH) as pub_month,
        COUNT(DISTINCT article_id) as article_count
    FROM {get_table_path('core', 'fct_articles')} a
    WHERE {where_clause}
        {author_filter}
        {keyword_filter}
    GROUP BY pub_month
    ORDER BY pub_month
    """
    monthly_df = run_query(client, monthly_query)

if not monthly_df.empty:
    fig_monthly = create_line_chart(
        monthly_df,
        x="pub_month",
        y="article_count",
        title="Number of Articles Published Each Month",
        height=400,
    )
    st.plotly_chart(fig_monthly, use_container_width=True)
else:
    st.info("No data available for the selected filters.")

# Average Word Count by Month
st.subheader("📊 Average Article Word Count by Month")

with st.spinner("Loading average word count by month..."):
    avg_wc_monthly_query = f"""
    SELECT
        DATE_TRUNC(pub_date, MONTH) as pub_month,
        ROUND(AVG(CASE WHEN word_count > 0 THEN word_count END), 0) as avg_word_count
    FROM {get_table_path('core', 'fct_articles')} a
    WHERE {where_clause}
        {author_filter}
        {keyword_filter}
    GROUP BY pub_month
    ORDER BY pub_month
    """
    avg_wc_monthly_df = run_query(client, avg_wc_monthly_query)

if not avg_wc_monthly_df.empty:
    fig_avg_wc = create_line_chart(
        avg_wc_monthly_df,
        x="pub_month",
        y="avg_word_count",
        title="Average Word Count by Month (positive values only)",
        height=400,
    )
    st.plotly_chart(fig_avg_wc, use_container_width=True)
else:
    st.info("No data available for the selected filters.")

st.markdown("---")

# Breakdowns section
col1, col2 = st.columns(2)

with col1:
    # Section breakdown
    st.subheader("📑 By Section")

    with st.spinner("Loading section breakdown..."):
        section_query = f"""
        SELECT
            section_name,
            COUNT(DISTINCT article_id) as article_count,
            ROUND(AVG(CASE WHEN word_count > 0 THEN word_count END), 0) as avg_word_count
        FROM {get_table_path('core', 'fct_articles')} a
        WHERE {where_clause}
            {author_filter}
            {keyword_filter}
        GROUP BY section_name
        ORDER BY article_count DESC
        LIMIT 15
        """
        section_df = run_query(client, section_query)

    if not section_df.empty:
        fig_section = create_bar_chart(
            section_df,
            x="section_name",
            y="article_count",
            title="Top 15 Sections by Article Count",
            height=350,
        )
        st.plotly_chart(fig_section, use_container_width=True)

        st.dataframe(
            section_df[["section_name", "article_count", "avg_word_count"]],
            hide_index=True,
            use_container_width=True,
            height=300,
        )
    else:
        st.info("No section data available.")

with col2:
    # News Desk breakdown
    st.subheader("🏢 By News Desk")

    with st.spinner("Loading news desk breakdown..."):
        news_desk_query = f"""
        SELECT
            news_desk,
            COUNT(DISTINCT article_id) as article_count,
            ROUND(AVG(CASE WHEN word_count > 0 THEN word_count END), 0) as avg_word_count
        FROM {get_table_path('core', 'fct_articles')} a
        WHERE {where_clause}
            {author_filter}
            {keyword_filter}
        GROUP BY news_desk
        ORDER BY article_count DESC
        LIMIT 15
        """
        news_desk_breakdown_df = run_query(client, news_desk_query)

    if not news_desk_breakdown_df.empty:
        fig_desk = create_bar_chart(
            news_desk_breakdown_df,
            x="news_desk",
            y="article_count",
            title="Top 15 News Desks by Article Count",
            height=350,
        )
        st.plotly_chart(fig_desk, use_container_width=True)

        st.dataframe(
            news_desk_breakdown_df[["news_desk", "article_count", "avg_word_count"]],
            hide_index=True,
            use_container_width=True,
            height=300,
        )
    else:
        st.info("No news desk data available.")

st.markdown("---")

# Type of Material breakdown
st.subheader("📄 By Type of Material")

with st.spinner("Loading material type breakdown..."):
    material_query = f"""
    SELECT
        type_of_material,
        COUNT(DISTINCT article_id) as article_count,
        ROUND(AVG(CASE WHEN word_count > 0 THEN word_count END), 0) as avg_word_count
    FROM {get_table_path('core', 'fct_articles')} a
    WHERE {where_clause}
        {author_filter}
        {keyword_filter}
    GROUP BY type_of_material
    ORDER BY article_count DESC
    LIMIT 15
    """
    material_df = run_query(client, material_query)

if not material_df.empty:
    col1, col2 = st.columns([2, 1])

    with col1:
        fig_material = create_bar_chart(
            material_df,
            x="type_of_material",
            y="article_count",
            title="Top 15 Material Types by Article Count",
            height=400,
        )
        st.plotly_chart(fig_material, use_container_width=True)

    with col2:
        st.dataframe(
            material_df[["type_of_material", "article_count", "avg_word_count"]],
            hide_index=True,
            use_container_width=True,
            height=400,
        )
else:
    st.info("No material type data available.")

st.markdown("---")

# Top Keywords and Authors
col1, col2 = st.columns(2)

with col1:
    st.subheader("🏷️ Top 10 Keywords")

    with st.spinner("Loading top keywords..."):
        if selected_keywords:
            # If keywords are filtered, show those specific keywords
            keywords_str = "', '".join([k.replace("'", "\\'") for k in selected_keywords])
            top_keywords_query = f"""
            SELECT
                keyword.value as keyword_value,
                COUNT(DISTINCT a.article_id) as article_count,
                ROUND(AVG(CASE WHEN a.word_count > 0 THEN a.word_count END), 0) as avg_word_count
            FROM {get_table_path('core', 'fct_articles')} a
            CROSS JOIN {get_table_path('staging', 'stg_archive_articles')} sa
            CROSS JOIN UNNEST(sa.keywords) as keyword
            WHERE a.article_id = sa.article_id
                AND keyword.value IN ('{keywords_str}')
                AND {where_clause}
                {author_filter}
            GROUP BY keyword.value
            ORDER BY article_count DESC
            LIMIT 10
            """
        else:
            top_keywords_query = f"""
            SELECT
                keyword.value as keyword_value,
                COUNT(DISTINCT a.article_id) as article_count,
                ROUND(AVG(CASE WHEN a.word_count > 0 THEN a.word_count END), 0) as avg_word_count
            FROM {get_table_path('core', 'fct_articles')} a
            INNER JOIN {get_table_path('staging', 'stg_archive_articles')} sa
                ON a.article_id = sa.article_id
            CROSS JOIN UNNEST(sa.keywords) as keyword
            WHERE {where_clause}
                {author_filter}
            GROUP BY keyword.value
            ORDER BY article_count DESC
            LIMIT 10
            """
        top_keywords_df = run_query(client, top_keywords_query)

    if not top_keywords_df.empty:
        st.dataframe(top_keywords_df, hide_index=True, use_container_width=True, height=400)
    else:
        st.info("No keyword data available.")

with col2:
    st.subheader("✍️ Top 10 Authors")

    with st.spinner("Loading top authors..."):
        if selected_authors:
            # If authors are filtered, show those specific authors
            authors_str = "', '".join([a.replace("'", "\\'") for a in selected_authors])
            top_authors_query = f"""
            SELECT
                TRIM(CONCAT(
                    COALESCE(author.firstname, ''),
                    ' ',
                    COALESCE(author.middlename, ''),
                    ' ',
                    COALESCE(author.lastname, '')
                )) as author_full_name,
                COUNT(DISTINCT a.article_id) as article_count,
                ROUND(AVG(CASE WHEN a.word_count > 0 THEN a.word_count END), 0) as avg_word_count
            FROM {get_table_path('core', 'fct_articles')} a
            INNER JOIN {get_table_path('staging', 'stg_archive_articles')} sa
                ON a.article_id = sa.article_id
            CROSS JOIN UNNEST(sa.byline_person) as author
            WHERE TRIM(CONCAT(
                    COALESCE(author.firstname, ''),
                    ' ',
                    COALESCE(author.middlename, ''),
                    ' ',
                    COALESCE(author.lastname, '')
                )) IN ('{authors_str}')
                AND {where_clause}
                {keyword_filter}
            GROUP BY author_full_name
            ORDER BY article_count DESC
            LIMIT 10
            """
        else:
            top_authors_query = f"""
            SELECT
                TRIM(CONCAT(
                    COALESCE(author.firstname, ''),
                    ' ',
                    COALESCE(author.middlename, ''),
                    ' ',
                    COALESCE(author.lastname, '')
                )) as author_full_name,
                COUNT(DISTINCT a.article_id) as article_count,
                ROUND(AVG(CASE WHEN a.word_count > 0 THEN a.word_count END), 0) as avg_word_count
            FROM {get_table_path('core', 'fct_articles')} a
            INNER JOIN {get_table_path('staging', 'stg_archive_articles')} sa
                ON a.article_id = sa.article_id
            CROSS JOIN UNNEST(sa.byline_person) as author
            WHERE {where_clause}
                {keyword_filter}
            GROUP BY author_full_name
            ORDER BY article_count DESC
            LIMIT 10
            """
        top_authors_df = run_query(client, top_authors_query)

    if not top_authors_df.empty:
        st.dataframe(top_authors_df, hide_index=True, use_container_width=True, height=400)
    else:
        st.info("No author data available.")

# Footer
st.markdown("---")
st.caption(
    """
**Note:**
- Only articles within the last 100 years are included (stray earlier articles filtered out)
- Average word counts exclude articles with 0 word count
- All filters are interconnected and apply to all visualizations
"""
)
