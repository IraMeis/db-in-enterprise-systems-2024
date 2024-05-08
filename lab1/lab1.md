# Лабораторная работа №1  

### Предметная область
Приложение для мониторинга качества воды. Есть **юзеры**, 
экспертные **группы** (юзер может быть в более чем одной группе),
юзеры могут производть **замеры** характеристик воды, каждое измерение 
ассоциируется с некоторым **водоемом**.

### ER модель
**Основные таблицы**  
sys_user - пользоваетель,  
sys_group - экспертная группа,  
reservoir - водоем (словарь),  
measurement - измерение.

**Дополнительные таблицы**  
link_sys_user_sys_group - для реализаци N:M юзер-группа,  
token - на беке предполагается jwt-авторизация, эта таблица для
хранения рефреш-токена, связь токена с юзером 1:1.

Кроме перечисленных связей имеются 1:N юзер-измерение,
1:N группа-измерение (измерение дополнительно 
привязывается к одной конкретной группе юзера), 
1:N водоем-измерение.  

**Структура таблиц**  
У всех основных таблиц есть общая часть:  
unique_id - primary key,  
uuid - уникальный по бд id (uuid_generate_v4()),  
created_timestamp - время создания записи,  
modified_timestamp - время последней модификации записи,  
is_deleted - признак удаленния записи (предполагается софт делет).  

sys_user  
login - имя в системе,  
password - хеш пароля,  
description -  описание в произвольной форме,  
first_name - имя,  
second_name - отчетсво/второе имя,  
last_name - фамилия,  
phone - телефон,  
email - почта,  
is_online - признак в сети/не в сети в текущий момент юзер.  

sys_group  
name - название группы,  
description - описание в произвольной форме.  

link_sys_user_sys_group  
sys_user_ref - fk id юзера,  
sys_group_ref - fk id группы,  
is_primary - признак первичной группы для юзера (группа по умолчанию),   
is_admin - признак наличия админских прав у юзера в группе.  

token  
content - byte значение токена,  
sys_user_ref fk id юзера.

reservoir  
name - название группы,  
description -  описание в произвольной форме.  

measurement  
lon - долгота места произведения замера,  
lat - широта места произведения замера,  
date - время прозведения замера,  
sys_user_ref - fk id юзера,  
sys_group_ref - fk id группы,  
reservoir_ref - fk id водоема,  
ph - кислотность,  
hardness - жесткость,  
solids - твердые вещества,  
chloramines - хлорамины,  
sulfate - сульфаты,  
conductivity - проводимость,  
organic carbon - органический углерод,  
trihalomethanes - тригалометаны,  
turbidity - мутность.  

[Скрипты создания таблиц](https://github.com/IraMeis/db-in-enterprise-systems-2024/blob/main/lab1/sql/00-init.sql)  

Бд доступна в докере:
`docker-compose -f docker-compose-db.yaml up`  


### Индексы  

primary key дефолтно посоздавал индексов по unique_id:  
`select * from pg_indexes where tablename not like 'pg%';`

[photo](https://github.com/IraMeis/db-in-enterprise-systems-2024/blob/main/lab1/img0.png)  

Дополнительно созданы индексы по столбцам, которые 
предположительно будут использованы для поиска. 
(Уникальные частичные по неудаленным записям на всякие
логины/телефоны/названия + обычный индекс по дате 
произведения замера)  

```
CREATE UNIQUE INDEX IF NOT EXISTS reservoir_name_unique_idx
ON public.reservoir USING btree (name) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS measurement_date_idx
ON public.measurement USING btree (date);
```  

[Скрипты создания индексов](https://github.com/IraMeis/db-in-enterprise-systems-2024/blob/main/lab1/sql/01-idx.sql)  

### Типовые запросы  

1 Получить водоем(ы), 
по которому(ым) имеется наибольшее количество измерений:
```
SELECT name FROM reservoir
WHERE unique_id IN (
	SELECT reservoir_ref FROM (
		SELECT reservoir_ref, count(*) AS num_rows
		FROM measurement
		GROUP BY reservoir_ref
		)
	WHERE num_rows = (
		SELECT MAX(num_rows) FROM (
		    SELECT reservoir_ref, count(*) AS num_rows
		    FROM measurement
		    GROUP BY reservoir_ref
		    )
    )
);
```

2 Получить токены юзеров, у которых измерений больше среднего:
```
SELECT t.content AS token_content
FROM token t
JOIN (
  SELECT sys_user_ref
  FROM (
    SELECT sys_user_ref, COUNT(*) AS count
    FROM measurement
    GROUP BY sys_user_ref
  ) AS user_measurement_count
  WHERE count > (
    SELECT AVG(count)
    FROM (
      SELECT sys_user_ref, COUNT(*) AS count
      FROM measurement
      GROUP BY sys_user_ref
    ) AS user_measurement_count
  )
) hu ON t.sys_user_ref = hu.sys_user_ref;
```

3 Получить группы у которых пользователей больше среднего 
и измерений меньше среднего:
```
SELECT DISTINCT g.unique_id
FROM sys_group g

JOIN (
  SELECT sys_group_ref, COUNT(*) AS user_count
  FROM link_sys_user_sys_group
  GROUP BY sys_group_ref
) u ON g.unique_id = u.sys_group_ref

JOIN (
  SELECT sys_group_ref, COUNT(*) AS measurement_count
  FROM measurement
  GROUP BY sys_group_ref
) m ON g.unique_id = m.sys_group_ref

WHERE
  u.user_count > (
    SELECT AVG(user_count)
    FROM (
      SELECT sys_group_ref, COUNT(*) AS user_count
      FROM link_sys_user_sys_group
      GROUP BY sys_group_ref
    ) avg_uc
  )

  AND m.measurement_count < (
    SELECT AVG(measurement_count)
    FROM (
      SELECT sys_group_ref, COUNT(*) AS measurement_count
      FROM measurement
      GROUP BY sys_group_ref
    ) avg_mc
  );
```

4 Получить водоемы, по которым делала замеры группа
с самым большим количеством измерений:

```
SELECT DISTINCT r.unique_id, r.name
FROM reservoir r
JOIN measurement m ON r.unique_id = m.reservoir_ref
JOIN (
    SELECT sys_group_ref, COUNT(*) AS measurement_count
    FROM measurement
    GROUP BY sys_group_ref
) mcg ON m.sys_group_ref = mcg.sys_group_ref
WHERE mcg.measurement_count = (
    SELECT MAX(grouped.measurement_count)
    FROM (
        SELECT sys_group_ref, COUNT(*) AS measurement_count
        FROM measurement
        GROUP BY sys_group_ref
    ) grouped
);
```

### Генерация тестовых данных  
[Скрипт](https://github.com/IraMeis/db-in-enterprise-systems-2024/blob/main/lab1/fill_data.ipynb)  

Генерация питоном (библиотеки faker и random), для 
записи использован psycopg2.  

Можно задать параметрами количество юзеров, групп,
водоемов, измерений, а также максимальное и минимальное
число юзеров в группах. В начале создаются коннекшн 
к локальной базе и курсор, каждой таблице соответствует
массив, после заполнения массива данные сразу записываются
в бд и далее массивы явно удаляются (чтоб лишнего 
не грузить память), данные, генерируемые самой бд (айди
и некоторые дефолтные значения) не заполняются питоном.  
В общем виде генерация + запись:

```
some_table = []

for i in range(num_rows):
    some_table.append(
        {
            'col1': val1,
            'col2': val2,
        }
    )

for row in some_table:
    cursor.execute('''INSERT INTO some_table (col1, col2) VALUES (%s, %s)''',
    (row['col1'],row['col2']))
```
По итогу на диске -2гб,  
[photo](https://github.com/IraMeis/db-in-enterprise-systems-2024/blob/main/lab1/img1.png)  

в таблицах записей:  
sys_user, token - 1 000 000  
sys_group - 10 000  
reservoir - 200 000  
measurement - 2 000 000  
link_sys_user_sys_group - 1 001 014  

### Время выполнения запросов & Оптимизации  

Характеристики среды:  
16ГБ RAM, intel 1.80GHz x 4 (8 - hyper-threading), ssd, os fedora39.  
Стейт до тестов:  
la 2-3 (браузеры, идеешки, питон и прочее -
гоняю на основной рабоче машине), 
память забита наполовину, не сваптися.  
Подопытная бд запускается в контейнере (докер) с
лимитами на память и проц, образ postgres:16.0-bookworm. 

Execution time для представленных запросов
получен через EXPLAIN ANALYSE $request.

| 1, мс | 2, мс  | 3, мс  | 4, мс  |
|-------|--------|--------|--------|
| 6945.791 | 3551.854 | 2681.970 | 5066.593 |


Первое что кажется не самой классной идеей -
запускать бд на 1 ядре (лимиты в докер-компос файле,
он у меня типовой для дев-нужд).
Оптимизации из категории "докупить железа" в таблице
ниже: 

| N    | 1, мс     | 2, мс    | 3, мс    | 4, мс    | ядра, шт | память, гб |
|------|-----------|----------|----------|----------|----------|------------|
| init | 6945.791  | 3551.854 | 2681.970 | 5066.593 | 1        | 4          |
| 1    | 2126.040  | 3588.414 | 1004.940 | 1608.460 | 2        | 4          |
| 2    | 1510.583  | 3731.507 | 727.061  | 1084.374 | 4        | 4          |
| 3    | 6669.712  | 3513.977 | 2778.486 | 5874.352 | 1        | 8          |
| 4    | 2239.959  | 3625.649 | 1034.630 | 1655.722 | 2        | 8          |
| 5    | 1498.518  | 3519.478 | 746.466  | 1067.816 | 4        | 8          |

В память "железа" запросы (при текущем конфиге сервера бд)
не упирались, а докидывание ядер позволило увеличить
скорость выполнения (в 5 раз максимально) 
для всех запросов кроме 2ого, который стойко 
выполняется около 3,6 сек.

Далее для тестов используется конфигурация
4 гб + 4 ядра.

Изменяемые параметры:  

**shared_buffers**  
Используется для кэширования данных. По дефолту
низкое значение, по доке рекомендуемое – 
25% от общей оперативной памяти.

**work_mem**  
Задаёт максимальный объём памяти,
который будет использоваться во внутренних операциях
(join, order by, distinct etc)
при обработке запросов, прежде чем будут 
задействованы временные файлы на диске. 

**random_page_cost и seq_page_cost**  
Относительная стоимость произвольного и последовательного
доступа к диску, дефолтно 4 и 1 (настроено под hdd),
на ssd есть смысл ставить билиже к 1:1.
При уменьшении random_page_cost по отношению 
к seq_page_cost система начинает предпочитать 
сканирование по индексу; при увеличении такое 
сканирование становится более дорогостоящим. Оба эти значения 
также можно увеличить или уменьшить одновременно, 
чтобы изменить стоимость операций ввода/вывода по 
отношению к стоимости процессорных операций.

| N    | 1, мс    | 2, мс   | 3, мс  | 4, мс    | shared_buffers, мб | work_mem, мб | random_page_cost / seq_page_cost |
|------|----------|---------|--------|----------|--------------------|----------|----------------------------------|
| init | 1510.583 | 3731.507 | 727.061 | 1084.374 | 128                | 4        | 4 / 1                            |
| 1    | 1562.850 | 3435.622 | 780.799 | 1080.409 | 1024               | 4        | 4 / 1                            |
| 2    | 1423.035 | 3318.524 | 695.869 | 987.437  | 2048               | 4        | 4 / 1                            |
| 3    | 1852.021 | 2616.159 | 669.490 | 957.676  | 2048               | 64       | 4 / 1                            |
| 4    | 1801.039 | 2532.980 | 659.836 | 927.085  | 2048               | 128      | 4 / 1                            |
| 5    | 1865.228 | 2522.809 | 695.457 | 1068.581 | 2048               | 128      | 1 / 1                            |
| 6    | 1881.103 | 2563.740 | 673.991 | 955.443  | 2048               | 128      | 0.1 / 0.1                        |
| 7    | 1953.309 | 2516.669 | 654.343 | 963.173  | 2048               | 128      | 0.01 / 0.01                      |

Интересное просиходит при установке work_mem в 64/128 мб -
время выполнения второго запроса сокращается на 1 сек,
а первый начинает наоборот проседать (на 0.3-0.5 сек). Изменения
shared_buffers и random_page_cost / seq_page_cost повлияли 
относительно мало.

Далее используется конфигурация 6.  

Оптимизации ~~которые надо было делать вначале~~ запросов  

Cделать меньше селектов, переписав все с использованием
cte:

1
```
WITH max_measurement_count AS (
    SELECT reservoir_ref, COUNT(*) AS measurement_count
    FROM measurement
    GROUP BY reservoir_ref
)
SELECT reservoir.name
FROM max_measurement_count
JOIN reservoir ON reservoir.unique_id = max_measurement_count.reservoir_ref
WHERE max_measurement_count.measurement_count = (
    SELECT MAX(measurement_count)
    FROM max_measurement_count
);
```

2
```
WITH user_measurement_counts AS (
    SELECT sys_user_ref, COUNT(*) AS measurement_count
    FROM measurement
    GROUP BY sys_user_ref
),
average_measurement_count AS (
    SELECT AVG(measurement_count) AS average_count
    FROM user_measurement_counts
),
users_above_average AS (
    SELECT sys_user_ref
    FROM user_measurement_counts
    WHERE measurement_count > (SELECT average_count FROM average_measurement_count)
)
SELECT t.content AS token_content
FROM token t
JOIN users_above_average ua
  ON t.sys_user_ref = ua.sys_user_ref;
```

3  
```
WITH 
group_user_count AS (
    SELECT sys_group_ref, COUNT(*) AS user_count
    FROM link_sys_user_sys_group
    GROUP BY sys_group_ref
),
group_measurement_count AS (
    SELECT sys_group_ref, COUNT(*) AS measurement_count
    FROM measurement
    GROUP BY sys_group_ref
),
avg_user_count AS (
    SELECT AVG(user_count) AS average_user_count
    FROM group_user_count
),
avg_measurement_count AS (
    SELECT AVG(measurement_count) AS average_measurement_count
    FROM group_measurement_count
)
SELECT DISTINCT g.unique_id
FROM sys_group g
JOIN group_user_count guc ON g.unique_id = guc.sys_group_ref
JOIN group_measurement_count gmc ON g.unique_id = gmc.sys_group_ref
WHERE 
    guc.user_count > (SELECT average_user_count FROM avg_user_count)
    AND gmc.measurement_count < (SELECT average_measurement_count FROM avg_measurement_count);

```

4  
```
WITH max_measurement_group AS (
    SELECT sys_group_ref, COUNT(*) AS measurement_count
    FROM measurement
    GROUP BY sys_group_ref
),
max_measurement_count AS (
    SELECT MAX(measurement_count) AS max_count
    FROM max_measurement_group
),
groups_with_max_measurement AS (
    SELECT sys_group_ref
    FROM max_measurement_group
    WHERE measurement_count = (SELECT max_count FROM max_measurement_count)
)
SELECT DISTINCT r.unique_id, r.name
FROM reservoir r
JOIN measurement m ON r.unique_id = m.reservoir_ref
JOIN groups_with_max_measurement gmm ON m.sys_group_ref = gmm.sys_group_ref;

```

| N               | 1, мс    | 2, мс   | 3, мс  | 4, мс     | 
|-----------------|----------|---------|--------|-----------|
| init            | 1510.583 | 3731.507 | 727.061 | 1084.374  |
| + server tuning | 1881.103 | 2563.740 | 673.991 | 955.443   | 
| + sql rewrite   | 1076.090 | 1848.065 | 351.986 | 670.096   | 


Результаты в целом радуют - все запросы получили ускорение 1.5-2
(хотя 2 сек sql как-то не впечатляет). ~~иногда нужно просто переписать 
плохой запрос и двигаться дальше~~  
Если сравнить эти оптимизации с первой табличкой, 
в которой просто добавлялись ядра,
и запросы ускорялись в 5 раз, то кажется что докидывание 
мощностей железа - классная идея, способная
решить все проблемы. Интереса ради я 
позапускала запросы на 8 ядрах и... ничего не изменилось. Потолок
"железных" оптимизаций достигнут, по крайней мере в 
услових лабораторной без 100500 одновременных коннекшенов и 
активного использования диска. 