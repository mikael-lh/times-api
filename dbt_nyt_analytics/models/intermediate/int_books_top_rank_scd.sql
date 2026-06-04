WITH weekly AS (
    SELECT
        primary_isbn13,
        published_date,
        min(rank) AS best_rank_that_week,
        array_agg(title ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS title,
        array_agg(publisher ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS publisher,
        array_agg(description ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS description,
        array_agg(age_group ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS age_group,
        array_agg(age_min ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS age_min,
        array_agg(age_max ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS age_max,
        array_agg(book_image ORDER BY list_name_encoded LIMIT 1)[offset(0)] AS book_image,
        array_agg(amazon_product_url ORDER BY list_name_encoded LIMIT 1
        )[offset(0)] AS amazon_product_url,
        array_agg(book_review_link ORDER BY list_name_encoded LIMIT 1
        )[offset(0)] AS book_review_link,
        array_agg(sunday_review_link ORDER BY list_name_encoded LIMIT 1
        )[offset(0)] AS sunday_review_link
    FROM {{ ref('stg_best_sellers') }}
    WHERE
        primary_isbn13 IS NOT NULL
        AND trim(primary_isbn13) != ''
    GROUP BY 1, 2
),

running AS (
    SELECT
        *,
        min(best_rank_that_week) OVER (
            PARTITION BY primary_isbn13
            ORDER BY published_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS top_rank
    FROM weekly
),

with_lags AS (
    SELECT
        *,
        lag(top_rank) OVER (
            PARTITION BY primary_isbn13
            ORDER BY published_date
        ) AS prev_top_rank,
        lag(struct(
            title,
            publisher,
            description,
            age_group,
            age_min,
            age_max,
            book_image,
            amazon_product_url,
            book_review_link,
            sunday_review_link
        )) OVER (
            PARTITION BY primary_isbn13
            ORDER BY published_date
        ) AS prev_attrs
    FROM running
),

flagged AS (
    SELECT
        *,
        CASE
            WHEN prev_top_rank IS NULL THEN 1
            WHEN top_rank != prev_top_rank THEN 1
            WHEN struct(
                title,
                publisher,
                description,
                age_group,
                age_min,
                age_max,
                book_image,
                amazon_product_url,
                book_review_link,
                sunday_review_link
            ) != prev_attrs THEN 1
            ELSE 0
        END AS is_new_version
    FROM with_lags
),

banded AS (
    SELECT
        *,
        sum(is_new_version) OVER (
            PARTITION BY primary_isbn13
            ORDER BY published_date
        ) AS scd_band
    FROM flagged
),

band_starts AS (
    SELECT *
    FROM banded
    QUALIFY row_number() OVER (
        PARTITION BY primary_isbn13, scd_band
        ORDER BY published_date
    ) = 1
),

isbn_dates AS (
    SELECT
        primary_isbn13,
        max(published_date) AS latest_published_date
    FROM weekly
    GROUP BY 1
),

with_valid_to AS (
    SELECT
        b.primary_isbn13,
        b.top_rank,
        b.published_date AS valid_from,
        b.title,
        b.publisher,
        b.description,
        b.age_group,
        b.age_min,
        b.age_max,
        b.book_image,
        b.amazon_product_url,
        b.book_review_link,
        b.sunday_review_link,
        d.latest_published_date,
        lead(b.published_date) OVER (
            PARTITION BY b.primary_isbn13
            ORDER BY b.published_date
        ) AS valid_to
    FROM band_starts AS b
    INNER JOIN isbn_dates AS d USING (primary_isbn13)
)

SELECT
    {{ generate_surrogate_key(['primary_isbn13', 'valid_from']) }} AS book_scd_key,
    primary_isbn13,
    title,
    publisher,
    description,
    age_group,
    age_min,
    age_max,
    top_rank,
    book_image,
    amazon_product_url,
    book_review_link,
    sunday_review_link,
    latest_published_date,
    valid_from,
    valid_to
FROM with_valid_to
