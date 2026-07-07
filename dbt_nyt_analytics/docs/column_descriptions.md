{# ============================================================ #}
{# Raw source columns — mirrored from schema/*.json            #}
{# archive_articles                                            #}
{# ============================================================ #}

{% docs article_id %}
Unique article identifier from NYT (_id).
{% enddocs %}

{% docs uri %}
Article URI.
{% enddocs %}

{% docs pub_date %}
Publication date (YYYY-MM-DD).
{% enddocs %}

{% docs section_name %}
Section name (e.g., Arts, Business).
{% enddocs %}

{% docs news_desk %}
News desk responsible for the article.
{% enddocs %}

{% docs type_of_material %}
Type of material (e.g., News, Opinion).
{% enddocs %}

{% docs document_type %}
Document type.
{% enddocs %}

{% docs word_count %}
Article word count.
{% enddocs %}

{% docs web_url %}
URL to the article on nytimes.com.
{% enddocs %}

{% docs headline_main %}
Main headline.
{% enddocs %}

{% docs byline_original %}
Original byline text.
{% enddocs %}

{% docs abstract %}
Article abstract.
{% enddocs %}

{% docs snippet %}
Article snippet.
{% enddocs %}

{% docs keywords %}
Array of keyword objects (name, value, rank, major).
{% enddocs %}

{% docs byline_person %}
Array of author objects (firstname, lastname, middlename, qualifier).
{% enddocs %}

{% docs multimedia_count_by_type %}
JSON object with multimedia counts by type.
{% enddocs %}

{# ============================================================ #}
{# Raw source columns — most_popular_articles                  #}
{# ============================================================ #}

{% docs snapshot_date %}
Date when this popularity snapshot was taken.
{% enddocs %}

{% docs mp_id %}
Article ID from the Most Popular API.
{% enddocs %}

{% docs url %}
Article URL.
{% enddocs %}

{% docs asset_id %}
Asset ID.
{% enddocs %}

{% docs source %}
Source (e.g., New York Times).
{% enddocs %}

{% docs published_date %}
Published date (STRING — requires parsing before use).
{% enddocs %}

{% docs updated %}
Updated date (STRING — requires parsing before use).
{% enddocs %}

{% docs section %}
Section name.
{% enddocs %}

{% docs subsection %}
Subsection name.
{% enddocs %}

{% docs byline %}
Byline text.
{% enddocs %}

{% docs type %}
Article type.
{% enddocs %}

{% docs title %}
Article title.
{% enddocs %}

{% docs des_facet %}
Description facets (array).
{% enddocs %}

{% docs org_facet %}
Organization facets (array).
{% enddocs %}

{% docs per_facet %}
Person facets (array).
{% enddocs %}

{% docs geo_facet %}
Geographic facets (array).
{% enddocs %}

{% docs media_count_by_type %}
Media count by type (JSON object).
{% enddocs %}

{% docs adx_keywords %}
ADX keywords string.
{% enddocs %}

{# ============================================================ #}
{# Raw source columns — best_sellers                           #}
{# ============================================================ #}

{% docs bs_published_date %}
Print publication date of the Best Sellers list (YYYY-MM-DD). Part of the composite primary key.
{% enddocs %}

{% docs list_name_encoded %}
URL-safe list identifier (e.g., hardcover-fiction). Part of the composite primary key.
{% enddocs %}

{% docs list_display_name %}
Human-readable list name (e.g., Hardcover Fiction).
{% enddocs %}

{% docs list_updated %}
How often the list is updated (weekly or monthly, normalized to lowercase). Part of the composite primary key.
{% enddocs %}

{% docs bs_rank %}
Rank on the list for this published_date. Part of the composite primary key.
{% enddocs %}

{% docs rank_last_week %}
Rank on the list in the previous publication (0 if new).
{% enddocs %}

{% docs weeks_on_list %}
Number of weeks the book has appeared on this list.
{% enddocs %}

{% docs asterisk %}
True if sales are barely distinguishable from those of the book above it.
{% enddocs %}

{% docs dagger %}
True if some retailers reported receiving bulk orders.
{% enddocs %}

{% docs primary_isbn13 %}
ISBN-13 identifier for the book (primary edition).
{% enddocs %}

{% docs book_title %}
Book title (title-cased for display).
{% enddocs %}

{% docs book_author %}
Book author as provided by the NYT Books API.
{% enddocs %}

{% docs contributor %}
Full contributor string (e.g., 'by Emily Henry').
{% enddocs %}

{% docs contributor_note %}
Additional contributor information (illustrator, translator, etc.).
{% enddocs %}

{% docs book_publisher %}
Publisher name.
{% enddocs %}

{% docs book_description %}
Short editorial description of the book.
{% enddocs %}

{% docs book_image %}
URL to the book cover image.
{% enddocs %}

{% docs amazon_product_url %}
Affiliate Amazon product URL.
{% enddocs %}

{% docs age_group %}
Target age group (used for children's lists).
{% enddocs %}

{% docs book_review_link %}
Link to NYT book review (if any).
{% enddocs %}

{% docs sunday_review_link %}
Link to NYT Sunday book review (if any).
{% enddocs %}

{% docs age_min %}
Minimum target age parsed from age_group (null when not applicable).
{% enddocs %}

{% docs age_max %}
Maximum target age parsed from age_group (null for open-ended ranges).
{% enddocs %}

{# ============================================================ #}
{# Staging-derived columns                                      #}
{# ============================================================ #}

{% docs published_at %}
Parsed publication timestamp (cast from the raw STRING published_date).
{% enddocs %}

{# ============================================================ #}
{# Intermediate-derived columns                                 #}
{# ============================================================ #}

{% docs keyword_name %}
Keyword category (e.g., subject, persons, organizations).
{% enddocs %}

{% docs keyword_value %}
The keyword value.
{% enddocs %}

{% docs keyword_rank %}
Rank of keyword relevance within the article.
{% enddocs %}

{% docs authors %}
Array of individual author names parsed from the book author field.
{% enddocs %}

{% docs latest_published_date %}
Most recent Best Sellers list publication date on which this book appeared.
{% enddocs %}

{% docs dbt_scd_id %}
Surrogate key for this SCD Type 2 snapshot row (managed by dbt).
{% enddocs %}

{% docs dbt_updated_at %}
Timestamp when dbt last updated this snapshot row.
{% enddocs %}

{% docs dbt_valid_from %}
Start of this version's validity window in the SCD Type 2 snapshot.
{% enddocs %}

{% docs dbt_valid_to %}
End of this version's validity window in the SCD Type 2 snapshot (null for the current row).
{% enddocs %}

{% docs author_full_name %}
Constructed full name of the author (firstname + lastname).
{% enddocs %}

{% docs firstname %}
Author first name.
{% enddocs %}

{% docs lastname %}
Author last name.
{% enddocs %}

{% docs middlename %}
Author middle name from archive bylines.
{% enddocs %}

{% docs qualifier %}
Author name suffix or qualifier from archive bylines (e.g., Jr., Sr.).
{% enddocs %}

{# ============================================================ #}
{# Core mart columns                                            #}
{# ============================================================ #}

{% docs author_key %}
Surrogate key for author (hashed from author_full_name).
{% enddocs %}

{% docs book_key %}
Surrogate key for book (hashed from primary_isbn13). Points to the current row in dim_books.
{% enddocs %}

{% docs book_scd_key %}
Surrogate key for a specific SCD Type 2 book version (hashed from primary_isbn13 and valid_from). Join to dim_books_history for point-in-time top_rank and metadata.
{% enddocs %}

{% docs top_rank %}
Best (lowest numeric) rank achieved across all Best Sellers lists for this book (current version on dim_books).
{% enddocs %}

{% docs top_rank_scd %}
Best (lowest numeric) rank achieved by this book as of this SCD version's validity window.
{% enddocs %}

{% docs valid_from %}
First Best Sellers list week when this top_rank version became effective for the book.
{% enddocs %}

{% docs valid_to %}
First list week of the next top_rank version (null for the current version).
{% enddocs %}

{% docs keyword_key %}
Surrogate key for keyword (hashed from keyword_name + keyword_value).
{% enddocs %}

{% docs section_key %}
Surrogate key for section (hashed from section_name + news_desk).
{% enddocs %}

{% docs author_count %}
Number of authors credited on the article.
{% enddocs %}

{% docs keyword_count %}
Number of keywords tagged on the article.
{% enddocs %}

{% docs days_since_published %}
Days elapsed between the article's publication date and the popularity snapshot date.
{% enddocs %}

{% docs keyword_major %}
Whether the keyword is a major keyword for the article (Y/N).
{% enddocs %}

{% docs major_keyword_count %}
Number of major keywords tagged on the article.
{% enddocs %}

{% docs has_keywords %}
Whether the article has at least one tagged keyword.
{% enddocs %}

{% docs has_authors %}
Whether the article has at least one credited author.
{% enddocs %}

{% docs has_multimedia %}
Whether the article has associated multimedia assets.
{% enddocs %}

{% docs updated_at %}
Parsed timestamp when the article was last updated in the Most Popular API.
{% enddocs %}

{% docs article_type %}
Article type from the Most Popular API (e.g., Article).
{% enddocs %}

{% docs description_facet_count %}
Number of description facets on the article in this popularity snapshot.
{% enddocs %}

{% docs organization_facet_count %}
Number of organization facets on the article in this popularity snapshot.
{% enddocs %}

{% docs person_facet_count %}
Number of person facets on the article in this popularity snapshot.
{% enddocs %}

{% docs geo_facet_count %}
Number of geographic facets on the article in this popularity snapshot.
{% enddocs %}

{% docs facet_key %}
Surrogate key for a conformed facet (hashed from facet_type and facet_value).
{% enddocs %}

{% docs facet_type %}
Type of facet: description, organization, person, or geographic.
{% enddocs %}

{% docs facet_value %}
String value of the facet.
{% enddocs %}

{# ============================================================ #}
{# Analytics mart columns                                       #}
{# ============================================================ #}

{% docs pub_month %}
Publication month (truncated to the first day of the month).
{% enddocs %}

{% docs pub_year %}
Publication year.
{% enddocs %}

{% docs total_articles %}
Total number of articles.
{% enddocs %}

{% docs avg_word_count %}
Average word count across articles.
{% enddocs %}

{% docs articles_with_authors %}
Count of articles with at least one credited author.
{% enddocs %}

{% docs articles_with_keywords %}
Count of articles with at least one tagged keyword.
{% enddocs %}

{% docs first_article_date %}
Date of the author's first published article.
{% enddocs %}

{% docs last_article_date %}
Date of the author's most recent published article.
{% enddocs %}

{% docs article_count %}
Number of articles.
{% enddocs %}

{% docs total_word_count %}
Total word count across articles in the aggregation grain.
{% enddocs %}

{% docs max_word_count %}
Maximum word count among articles in the aggregation grain.
{% enddocs %}

{% docs articles_with_multimedia %}
Count of articles with at least one multimedia asset.
{% enddocs %}

{% docs avg_authors_per_article %}
Average number of credited authors per article.
{% enddocs %}

{% docs avg_keywords_per_article %}
Average number of tagged keywords per article.
{% enddocs %}

{% docs unique_sections %}
Count of distinct section names in the aggregation grain.
{% enddocs %}

{% docs unique_news_desks %}
Count of distinct news desks in the aggregation grain.
{% enddocs %}

{% docs unique_material_types %}
Count of distinct material types in the aggregation grain.
{% enddocs %}

{% docs pct_with_authors %}
Percentage of articles with at least one credited author.
{% enddocs %}

{% docs pct_with_keywords %}
Percentage of articles with at least one tagged keyword.
{% enddocs %}

{% docs pct_with_multimedia %}
Percentage of articles with at least one multimedia asset.
{% enddocs %}

{% docs career_span_days %}
Number of days between the author's first and last published article.
{% enddocs %}

{% docs years_active %}
Count of distinct publication years in which the author published.
{% enddocs %}

{% docs first_year %}
Earliest publication year for the author.
{% enddocs %}

{% docs last_year %}
Most recent publication year for the author.
{% enddocs %}

{% docs total_words_written %}
Total words written across all of the author's articles.
{% enddocs %}

{% docs longest_article_words %}
Word count of the author's longest article.
{% enddocs %}

{% docs sections_written_for %}
Count of distinct sections the author has written for.
{% enddocs %}

{% docs articles_per_year %}
Average number of articles published per active year.
{% enddocs %}

{% docs year_total %}
Total articles published in the year across all sections and desks.
{% enddocs %}

{% docs pct_of_year_total %}
Section and desk share of total articles published in the year (percentage).
{% enddocs %}

{% docs avg_authors %}
Average number of credited authors per article in the aggregation grain.
{% enddocs %}

{% docs avg_keywords %}
Average number of tagged keywords per article in the aggregation grain.
{% enddocs %}

{% docs prior_year_count %}
Metric value for the prior publication year (used for year-over-year comparisons).
{% enddocs %}

{% docs yoy_change %}
Absolute year-over-year change from the prior year.
{% enddocs %}

{% docs yoy_change_pct %}
Year-over-year percentage change from the prior year.
{% enddocs %}

{% docs keyword_occurrences %}
Total keyword tag occurrences (includes multiple tags per article).
{% enddocs %}

{% docs rank_in_year %}
Rank of the keyword by distinct article count within the publication year.
{% enddocs %}

{% docs prior_year_rank %}
Rank of the keyword in the prior publication year.
{% enddocs %}

{% docs rank_change %}
Change in year rank from the prior year (positive means moved up in rank).
{% enddocs %}
