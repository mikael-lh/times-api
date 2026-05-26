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

{% docs book_key %}
Surrogate key for book (hashed from primary_isbn13).
{% enddocs %}

{% docs top_rank %}
Best (lowest numeric) rank achieved across all Best Sellers lists for this book.
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
