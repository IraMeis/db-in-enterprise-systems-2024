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

[Скрипты создания таблиц]()  

Бд доступна в докере:
`docker-compose -f docker-compose-db.yaml up`  


### Индексы  

primary key дефолтно посоздавал индексов по unique_id:  
`select * from pg_indexes where tablename not like 'pg%';`

[photo]()  

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

[Скрипты создания индексов]()  

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


### Время выполнения запросов  


### Оптимизации  




