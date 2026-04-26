-- Запрос 1: Общая статистика по жанрам
SELECT
    g.genre,
    COUNT(DISTINCT f.film_id)          AS film_count,
    ROUND(AVG(f.vote_average), 2)      AS avg_rating,
    ROUND(AVG(f.runtime), 0)           AS avg_runtime_min,
    ROUND(AVG(f.budget) / 1e6, 1)     AS avg_budget_mln,
    ROUND(AVG(fm.roi), 2)              AS avg_roi
FROM films f
JOIN film_genres g  ON f.film_id = g.film_id
JOIN financial_metrics fm ON f.film_id = fm.film_id
WHERE f.vote_count >= 10
  AND f.budget > 1000000
  AND f.revenue > 0
  AND g.genre NOT IN ('Unknown', '')
GROUP BY g.genre
HAVING film_count >= 50
ORDER BY avg_rating DESC;


-- Запрос 2: Динамика рынка по годам с оконной функцией
SELECT
    release_year,
    COUNT(*)                              AS film_count,
    ROUND(AVG(vote_average), 2)           AS avg_rating,
    ROUND(AVG(AVG(vote_average)) OVER (
        ORDER BY release_year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                 AS moving_avg_3y,
    ROUND(SUM(budget) / 1e9, 1)          AS total_budget_bln
FROM films
WHERE release_year BETWEEN 1980 AND 2024
  AND vote_count >= 10
GROUP BY release_year
ORDER BY release_year;


-- Запрос 3: Топ-3 фильма по ROI в каждом жанре
SELECT * FROM (
    SELECT
        g.genre,
        f.title,
        f.release_year,
        ROUND(fm.roi, 1)              AS roi,
        ROUND(fm.profit / 1e6, 1)    AS profit_mln,
        f.vote_average,
        RANK() OVER (
            PARTITION BY g.genre
            ORDER BY fm.roi DESC
        ) AS rank_in_genre
    FROM films f
    JOIN film_genres g  ON f.film_id = g.film_id
    JOIN financial_metrics fm ON f.film_id = fm.film_id
    WHERE f.budget > 1000000
      AND g.genre NOT IN ('Unknown', '')
) ranked
WHERE rank_in_genre <= 3
ORDER BY genre, rank_in_genre;


-- Запрос 4: Сегментация фильмов
SELECT
    CASE
        WHEN budget > 100000000 AND vote_average >= 7 THEN 'Успешный блокбастер'
        WHEN budget > 100000000 AND vote_average < 7  THEN 'Дорогой провал'
        WHEN budget BETWEEN 1000000 AND 100000000
             AND vote_average >= 7                    THEN 'Инди-жемчужина'
        WHEN budget BETWEEN 1000000 AND 100000000
             AND vote_average < 7                     THEN 'Обычный фильм'
        ELSE 'Без данных о бюджете'
    END                                AS segment,
    COUNT(*)                           AS film_count,
    ROUND(AVG(vote_average), 2)        AS avg_rating,
    ROUND(AVG(CASE WHEN f.budget > 0 AND f.revenue > 0
                   THEN fm.roi END), 2) AS avg_roi,
    ROUND(AVG(fm.profit) / 1e6, 1)    AS avg_profit_mln
FROM films f
JOIN financial_metrics fm ON f.film_id = fm.film_id
WHERE vote_count >= 50
  AND segment != 'Без данных о бюджете'
GROUP BY segment
ORDER BY avg_rating DESC;


-- Запрос 5: Фильмы выше среднего рейтинга своего жанра
SELECT
    f.title,
    f.release_year,
    g.genre,
    f.vote_average,
    ROUND(genre_avg.avg_rating, 2)          AS genre_avg_rating,
    ROUND(f.vote_average
          - genre_avg.avg_rating, 2)         AS above_avg_by
FROM films f
JOIN film_genres g ON f.film_id = g.film_id
JOIN (
    SELECT
        fg.genre,
        AVG(fl.vote_average) AS avg_rating
    FROM film_genres fg
    JOIN films fl ON fg.film_id = fl.film_id
    WHERE fl.vote_count >= 10
    GROUP BY fg.genre
) genre_avg ON g.genre = genre_avg.genre
WHERE f.vote_average > genre_avg.avg_rating
  AND f.vote_count >= 100
  AND g.genre NOT IN ('Unknown', '')
ORDER BY above_avg_by DESC
LIMIT 20;