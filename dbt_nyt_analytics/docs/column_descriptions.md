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

{% docs author_full_name %}
Constructed full name of the author (firstname + lastname).
{% enddocs %}

{% docs firstname %}
Author first name.
{% enddocs %}

{% docs lastname %}
Author last name.
{% enddocs %}

{# ============================================================ #}
{# Core mart columns                                            #}
{# ============================================================ #}

{% docs author_key %}
Surrogate key for author (hashed from author_full_name).
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
