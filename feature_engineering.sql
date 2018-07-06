-- BigQueryで特徴エンジニアリングをする
-- append test to train
SELECT
  item_id, user_id, region, city, parent_category_name, category_name, param_1, param_2, param_3, title, description, price, item_seq_number, activation_date,
  user_type, image, image_top_1, deal_probability
FROM
  `bqtest-114514.avito.train`
UNION ALL
SELECT
  item_id, user_id, region, city, parent_category_name, category_name, param_1, param_2, param_3, title, description, price, item_seq_number, activation_date,
  user_type, image, image_top_1, NULL AS deal_probability
FROM
  `bqtest-114514.avito.test`
-- > 約210万行のデータ


-- EDA

-- Cheking groups and counts of Categorical variables
-- 0. item_id
SELECT item_id, count(item_id) as item_id_count FROM [bqtest-114514:avito.train_test] group by item_id
-- > item_idの重複なし．特徴量として捨ててよい

-- 1. user_type
SELECT user_type, count(user_type) as user_type_count FROM [bqtest-114514:avito.train_test]  group by user_type order by user_type_count
-- > [3 categories]　約3/4がPrivate のこり1/4がshop company

-- 2. parent_category_name
SELECT parent_category_name, COUNT(parent_category_name) AS parent_category_name_count FROM [bqtest-114514:avito.train_test] GROUP BY parent_category_name
-- > [9 categories]

-- 3. category_name
SELECT category_name, COUNT(category_name) AS category_name_count FROM [bqtest-114514:avito.train_test] GROUP BY category_name
-- > [47 categories]

-- 4. region
SELECT region, COUNT(region) AS region_count FROM [bqtest-114514:avito.train_test] GROUP BY region
-- > [28 categories]

-- 5. city
SELECT city, COUNT(city) AS city_count FROM [bqtest-114514:avito.train_test] GROUP BY city order by city_count DESC
-- > [1733 categories] このデータは現実的にone-hot使えない

-- 6. param_1
SELECT param_1, COUNT(param_1) AS param_1_count FROM [bqtest-114514:avito.train_test] GROUP BY param_1
-- > [372 categories]

-- 7. param_2
SELECT param_2, COUNT(param_2) AS param_2_count FROM [bqtest-114514:avito.train_test] GROUP BY param_2
-- > [272 categories? ]　メーカー名とかブランド名とかが書いてある．カテゴリとして扱ってよいのか?

-- 8. param_3
SELECT param_3, COUNT(param_3) AS param_3_count FROM [bqtest-114514:avito.train_test] GROUP BY param_3
-- > [1220 categories?] 車の名前とか，適当な数値とかが入っているからカテゴリ変数ではなさそう．商品名とかの備考記述テキストっぽい　カテゴリといえばカテゴリか・・・

-- 9. item_seq_number
SELECT item_seq_number, count(1) as item_seq_number_count FROM [bqtest-114514:avito.train_test] group by item_seq_number order by item_seq_number_count desc
-- > 1から順にパケット送受信があったらランダムに割り振るらしい．正直使いどころがよくわからん（1が多すぎるのでたぶん罠）

-- 10. image_count
SELECT image, count(1) as image_count FROM [bqtest-114514:avito.train_test] group by image order by image_count desc
-- > 画像なし：155197, 画像あり：1856666 - 155197 = 1701469  約92％は画像あり．（のこりの8％くらいなら，画像をGANで生成すればいいのでは？）

-- 10.5 image_count(testデータのみ)
SELECT image, count(1) as image_count FROM [bqtest-114514:avito.test] group by image order by image_count desc
-- > 画像なし： 42609 約91％は画像あり．　画像の配分は，学習，テストデータともに同じくらい．


-- (おまけ)user_id
SELECT user_id, count(user_id) as user_id_count FROM [bqtest-114514:avito.train_test] group by user_id ORDER BY user_id_count DESC
-- > 100万グループ程度．購入ユーザの比率に大きな偏りがある．（買う人はかなり買う．）


-- 上位のuser_idがどのuser_typeか調査
SELECT user_id, user_type, count(user_id) as user_id_count FROM [bqtest-114514:avito.train_test] group by user_id, user_type order by user_id_count desc
-- > 上位はほとんどshopかcompany 116位でようやく個人 下位はほとんど個人(だいたい40個以下くらいから買い始める)

-- 1?. 親子，param1-3カテゴリのそれぞれの組み合わせに対するカウント数調査
SELECT
  parent_category_name, category_name, param_1, param_2, param_3, COUNT(1) AS parent_child_param_1_2_3_count
FROM [bqtest-114514:avito.train_test]
GROUP BY parent_category_name, category_name, param_1, param_2, param_3
ORDER BY parent_child_param_1_2_3_count DESC

-- 地方-市名(region-city) count
SELECT
  region, city, COUNT(1) AS region_city_count
FROM [bqtest-114514:avito.train_test]
GROUP BY region, city
ORDER BY region_city_count DESC

-- 商品に対する地域特性を見るのであれば，region(-city)と商品カテゴリの組み合わせを見ればよさそう．
SELECT
  region, city, parent_category_name, category_name, param_1, param_2, param_3, COUNT(1) AS region_city_all_category_count
FROM [bqtest-114514:avito.train_test]
GROUP BY region, city, parent_category_name, category_name, param_1, param_2, param_3
ORDER BY region_city_all_category_count DESC

-- 商品に対するユーザタイプの特性の場合も似たような感じで．
SELECT
  user_id, parent_category_name, category_name, param_1, param_2, param_3, COUNT(1) AS user_id_all_category_count
FROM [bqtest-114514:avito.train_test]
GROUP BY user_id, parent_category_name, category_name, param_1, param_2, param_3
ORDER BY user_id_all_category_count DESC

-- ユーザーと地域の関係性
SELECT
  user_id, region, city, COUNT(1) AS user_id_region_city_count
FROM [bqtest-114514:avito.train_test]
GROUP BY user_id, region, city
ORDER BY user_id_region_city_count DESC

-- ユーザと地域とカテゴリの特性
SELECT
  user_id, region, city, parent_category_name, category_name, COUNT(1) AS user_id_region_city_parent_child_category_count
FROM [bqtest-114514:avito.train_test]
GROUP BY user_id, region, city, parent_category_name, category_name
ORDER BY user_id_region_city_parent_child_category_count DESC

-- user_id と価格の組み合わせカウント数 (user_id絡みはかなり効くっぽい)
SELECT user_id, price, count(1) as user_id_price_count
FROM `bqtest-114514.avito.train_test` 
group by user_id, price

-- timediff
-- 前カテゴリにおいて，カテゴリ内のativation_timeの最大最小差分を計算
SELECT
  user_id,
  region,
  city,
  parent_category_name,
  category_name,
  param_1,
  param_2,
  param_3,
  user_type,
  COUNT(1) AS user_id_region_city_parent_child_category_count,
  TIMESTAMP_DIFF(MAX(TIMESTAMP(activation_date)), MIN(TIMESTAMP(activation_date)), DAY) AS diff
FROM
  `bqtest-114514.avito.train_test`
GROUP BY
  user_id,
  region,
  city,
  parent_category_name,
  category_name,
  param_1,
  param_2,
  param_3,
  user_type
ORDER BY
  user_id_region_city_parent_child_category_count DESC


-- Unique数 
-- unique 数の調査例 count(1) as cnt == COUNT(parent_category_name)　という意味
-- 1. 親子カテゴリのユニーク数調査
SELECT parent_category_name, count(1) as cnt, COUNT(distinct category_name) AS category_name_unique FROM [bqtest-114514:avito.train_test] GROUP BY parent_category_name
-- > 親カテゴリ数，各親カテゴリの総数，各親カテゴリに対して子カテゴリのユニーク数（重複なしのカウント数．つまり子カテゴリの種類数）がどのくらい出るかを示す．

-- 2. 地方-市名のユニーク数調査
SELECT region, count(1) as region_count, COUNT(distinct city) AS city_unique FROM [bqtest-114514:avito.train_test] GROUP BY region order by region_count desc
-- > それぞれの地方にたいして，だいたいまんべんない市で購入されているっぽい．

-- 3. user_idに対する価格のユニーク数　(user_id絡みの変数はGainがでかそう)
SELECT user_id, count(distinct price) as user_id_price_unique
FROM `bqtest-114514.avito.train_test` 
group by user_id



-- 特徴作成
-- とりあえず第一段階
SELECT
  t.item_id,
  t.user_id,
  t.region,
  t.city,
  t.parent_category_name,
  t.category_name,
  t.param_1,
  t.param_2,
  t.param_3,
  t.user_type,
  t.price,
  IFNULL(all_diff.diff, 0) AS diff,
  acuq.category_name_unique,
  IFNULL(acc.parent_child_param_1_2_3_count, 0) AS all_category_count,
  rcuq.city_unique,
  IFNULL(rcc.region_city_count, 0) AS region_city_count,
  IFNULL(rc_allc_c.region_city_all_category_count, 0) AS region_city_all_category_count,
  IFNULL(ui_allc_c.user_id_all_category_count, 0) AS user_id_all_category_count,
  IFNULL(uircc.user_id_region_city_count, 0) AS user_id_region_city_count,
  IFNULL(uircpccc.user_id_region_city_parent_child_category_count, 0) AS user_id_region_city_parent_child_category_count,
  image_top_1,
  deal_probability
  
FROM
  `bqtest-114514.avito.train_test` AS t

LEFT OUTER JOIN
  `avito._all_category_count_diff` AS all_diff
ON
  t.user_id = all_diff.user_id
  AND t.region = all_diff.region
  AND t.city = all_diff.city
  AND t.parent_category_name = all_diff.parent_category_name
  AND t.category_name = all_diff.category_name
  AND t.param_1 = all_diff.param_1
  AND t.param_2 = all_diff.param_2
  AND t.param_3 = all_diff.param_3
  AND t.user_type = all_diff.user_type

LEFT OUTER JOIN
  `avito._parent_child_category_unique` AS acuq
ON
  t.parent_category_name = acuq.parent_category_name

LEFT OUTER JOIN
  `avito._parent_child_param_1_2_3_count` AS acc
ON
  t.parent_category_name = acc.parent_category_name
  AND t.category_name = acc.category_name
  AND t.param_1 = acc.param_1
  AND t.param_2 = acc.param_2
  AND t.param_3 = acc.param_3

LEFT OUTER JOIN
  `avito._region_city_unique` AS rcuq
ON
  t.region = rcuq.region

LEFT OUTER JOIN
  `avito._region_city_count` AS rcc
ON
  t.region = rcc.region
  AND t.city = rcc.city

LEFT OUTER JOIN
  `avito._region_city_all_category_count` AS rc_allc_c
ON
  t.region = rc_allc_c.region
  AND t.city = rc_allc_c.city
  AND t.parent_category_name = rc_allc_c.parent_category_name
  AND t.category_name = rc_allc_c.category_name
  AND t.param_1 = rc_allc_c.param_1
  AND t.param_2 = rc_allc_c.param_2
  AND t.param_3 = rc_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_all_category_count` AS ui_allc_c
ON
  t.user_id = ui_allc_c.user_id
  AND t.parent_category_name = ui_allc_c.parent_category_name
  AND t.category_name = ui_allc_c.category_name
  AND t.param_1 = ui_allc_c.param_1
  AND t.param_2 = ui_allc_c.param_2
  AND t.param_3 = ui_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_region_city_count` AS uircc
ON
  t.user_id = uircc.user_id
  AND t.region = uircc.region
  AND t.city = uircc.city

LEFT OUTER JOIN
  `avito._user_id_region_city_parent_child_category_count` AS uircpccc
ON
  t.user_id = uircpccc.user_id
  AND t.parent_category_name = uircpccc.parent_category_name
  AND t.category_name = uircpccc.category_name
  AND t.region = uircpccc.region
  AND t.city = uircpccc.city


-- 第二段階 (user_idが色々効いていそうなのでこの辺りを探索する)
SELECT
  t.item_id,
  t.user_id,
  t.region,
  t.city,
  t.parent_category_name,
  t.category_name,
  t.param_1,
  t.param_2,
  t.param_3,
  t.user_type,
  t.price,
  IFNULL(all_diff.diff, 0) AS diff,
  acuq.category_name_unique,
  IFNULL(acc.parent_child_param_1_2_3_count, 0) AS all_category_count,
  rcuq.city_unique,
  IFNULL(rcc.region_city_count, 0) AS region_city_count,
  IFNULL(rc_allc_c.region_city_all_category_count, 0) AS region_city_all_category_count,
  IFNULL(ui_allc_c.user_id_all_category_count, 0) AS user_id_all_category_count,
  IFNULL(uircc.user_id_region_city_count, 0) AS user_id_region_city_count,
  IFNULL(uircpccc.user_id_region_city_parent_child_category_count, 0) AS user_id_region_city_parent_child_category_count,
  image_top_1,
  -- 追加
  IFNULL(uipc.user_id_price_count, 0) AS user_id_price_count,
  uipuq.user_id_price_unique,
  
  deal_probability
  
FROM
  `bqtest-114514.avito.train_test` AS t

LEFT OUTER JOIN
  `avito._all_category_count_diff` AS all_diff
ON
  t.user_id = all_diff.user_id
  AND t.region = all_diff.region
  AND t.city = all_diff.city
  AND t.parent_category_name = all_diff.parent_category_name
  AND t.category_name = all_diff.category_name
  AND t.param_1 = all_diff.param_1
  AND t.param_2 = all_diff.param_2
  AND t.param_3 = all_diff.param_3
  AND t.user_type = all_diff.user_type

LEFT OUTER JOIN
  `avito._parent_child_category_unique` AS acuq
ON
  t.parent_category_name = acuq.parent_category_name

LEFT OUTER JOIN
  `avito._parent_child_param_1_2_3_count` AS acc
ON
  t.parent_category_name = acc.parent_category_name
  AND t.category_name = acc.category_name
  AND t.param_1 = acc.param_1
  AND t.param_2 = acc.param_2
  AND t.param_3 = acc.param_3

LEFT OUTER JOIN
  `avito._region_city_unique` AS rcuq
ON
  t.region = rcuq.region

LEFT OUTER JOIN
  `avito._region_city_count` AS rcc
ON
  t.region = rcc.region
  AND t.city = rcc.city

LEFT OUTER JOIN
  `avito._region_city_all_category_count` AS rc_allc_c
ON
  t.region = rc_allc_c.region
  AND t.city = rc_allc_c.city
  AND t.parent_category_name = rc_allc_c.parent_category_name
  AND t.category_name = rc_allc_c.category_name
  AND t.param_1 = rc_allc_c.param_1
  AND t.param_2 = rc_allc_c.param_2
  AND t.param_3 = rc_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_all_category_count` AS ui_allc_c
ON
  t.user_id = ui_allc_c.user_id
  AND t.parent_category_name = ui_allc_c.parent_category_name
  AND t.category_name = ui_allc_c.category_name
  AND t.param_1 = ui_allc_c.param_1
  AND t.param_2 = ui_allc_c.param_2
  AND t.param_3 = ui_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_region_city_count` AS uircc
ON
  t.user_id = uircc.user_id
  AND t.region = uircc.region
  AND t.city = uircc.city

LEFT OUTER JOIN
  `avito._user_id_region_city_parent_child_category_count` AS uircpccc
ON
  t.user_id = uircpccc.user_id
  AND t.parent_category_name = uircpccc.parent_category_name
  AND t.category_name = uircpccc.category_name
  AND t.region = uircpccc.region
  AND t.city = uircpccc.city

-- ここから追加
LEFT OUTER JOIN
  `avito._user_id_price_count` AS uipc
ON
  t.user_id = uipc.user_id
  AND t.price = uipc.price

LEFT OUTER JOIN
  `avito._user_id_price_unique` AS uipuq
ON
  t.user_id = uipuq.user_id
  

-- 第三段階
-- activation_date を　month, day　に分解
-- activation date を　初期値からdiffをとって単位dayで差分を表す

-- part_1

SELECT
  t.item_id,
  t.user_id,
  t.region,
  t.city,
  t.parent_category_name,
  t.category_name,
  t.param_1,
  t.param_2,
  t.param_3,
  t.user_type,
  t.price,
  EXTRACT(MONTH FROM TIMESTAMP(t.activation_date)) as month,
  EXTRACT(DAY FROM TIMESTAMP(t.activation_date)) as day,
  DATE_DIFF(activation_date, DATE("2017-03-15"), DAY) as day_diff,
  IFNULL(all_diff.diff, 0) AS all_categ_minmax_diff,
  acuq.category_name_unique,
  IFNULL(acc.parent_child_param_1_2_3_count, 0) AS all_category_count,
  rcuq.city_unique,
  IFNULL(rcc.region_city_count, 0) AS region_city_count,
  IFNULL(rc_allc_c.region_city_all_category_count, 0) AS region_city_all_category_count,
  IFNULL(ui_allc_c.user_id_all_category_count, 0) AS user_id_all_category_count,
  IFNULL(uircc.user_id_region_city_count, 0) AS user_id_region_city_count,
  IFNULL(uircpccc.user_id_region_city_parent_child_category_count, 0) AS user_id_region_city_parent_child_category_count,
  image_top_1,
  IFNULL(uipc.user_id_price_count, 0) AS user_id_price_count,
  uipuq.user_id_price_unique,
  deal_probability
  
FROM
  `bqtest-114514.avito.train_test` AS t

LEFT OUTER JOIN
  `avito._all_category_count_diff` AS all_diff
ON
  t.user_id = all_diff.user_id
  AND t.region = all_diff.region
  AND t.city = all_diff.city
  AND t.parent_category_name = all_diff.parent_category_name
  AND t.category_name = all_diff.category_name
  AND t.param_1 = all_diff.param_1
  AND t.param_2 = all_diff.param_2
  AND t.param_3 = all_diff.param_3
  AND t.user_type = all_diff.user_type

LEFT OUTER JOIN
  `avito._parent_child_category_unique` AS acuq
ON
  t.parent_category_name = acuq.parent_category_name

LEFT OUTER JOIN
  `avito._parent_child_param_1_2_3_count` AS acc
ON
  t.parent_category_name = acc.parent_category_name
  AND t.category_name = acc.category_name
  AND t.param_1 = acc.param_1
  AND t.param_2 = acc.param_2
  AND t.param_3 = acc.param_3

LEFT OUTER JOIN
  `avito._region_city_unique` AS rcuq
ON
  t.region = rcuq.region

LEFT OUTER JOIN
  `avito._region_city_count` AS rcc
ON
  t.region = rcc.region
  AND t.city = rcc.city

LEFT OUTER JOIN
  `avito._region_city_all_category_count` AS rc_allc_c
ON
  t.region = rc_allc_c.region
  AND t.city = rc_allc_c.city
  AND t.parent_category_name = rc_allc_c.parent_category_name
  AND t.category_name = rc_allc_c.category_name
  AND t.param_1 = rc_allc_c.param_1
  AND t.param_2 = rc_allc_c.param_2
  AND t.param_3 = rc_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_all_category_count` AS ui_allc_c
ON
  t.user_id = ui_allc_c.user_id
  AND t.parent_category_name = ui_allc_c.parent_category_name
  AND t.category_name = ui_allc_c.category_name
  AND t.param_1 = ui_allc_c.param_1
  AND t.param_2 = ui_allc_c.param_2
  AND t.param_3 = ui_allc_c.param_3

LEFT OUTER JOIN
  `avito._user_id_region_city_count` AS uircc
ON
  t.user_id = uircc.user_id
  AND t.region = uircc.region
  AND t.city = uircc.city

LEFT OUTER JOIN
  `avito._user_id_region_city_parent_child_category_count` AS uircpccc
ON
  t.user_id = uircpccc.user_id
  AND t.parent_category_name = uircpccc.parent_category_name
  AND t.category_name = uircpccc.category_name
  AND t.region = uircpccc.region
  AND t.city = uircpccc.city

LEFT OUTER JOIN
  `avito._user_id_price_count` AS uipc
ON
  t.user_id = uipc.user_id
  AND t.price = uipc.price

LEFT OUTER JOIN
  `avito._user_id_price_unique` AS uipuq
ON
  t.user_id = uipuq.user_id


--第3.2段階 all_categ_minmax_diff
-- 13個のカテゴリ・量的変数から全組み合わせでカウントをとっていく
-- 13C1, 13C2, ...

SELECT
  t.item_id,
  t.user_id,
  t.region,
  t.city,
  t.parent_category_name,
  t.category_name,
  t.param_1,
  t.param_2,
  t.param_3,
  t.user_type,
  t.price,
  t.day_diff,
  t.all_categ_minmax_diff,
  t.category_name_unique,
  t.all_category_count,
  t.city_unique,
  t.region_city_count,
  t.region_city_all_category_count,
  t.user_id_all_category_count,
  t.user_id_region_city_count,
  t.user_id_region_city_parent_child_category_count,
  t.image_top_1,
  t.user_id_price_count,
  t.user_id_price_unique,
  -- ここから追加
  IFNULL(acmdit1c.all_categ_minmax_diff_image_top_1_count, 0) AS all_categ_minmax_diff_image_top_1_count,
  IFNULL(cnacmdc.category_name_all_categ_minmax_diff_count, 0) AS category_name_all_categ_minmax_diff_count,
  IFNULL(cnc.category_name_count, 0) AS category_name_count,
  IFNULL(cnddc.category_name_day_diff_count, 0) AS category_name_day_diff_count,
  IFNULL(cnit1c.category_name_image_top_1_count, 0) AS category_name_image_top_1_count,
  IFNULL(cnp1c.category_name_param_1_count, 0) AS category_name_param_1_count,
  IFNULL(cnp2c.category_name_param_2_count, 0) AS category_name_param_2_count,
  IFNULL(cnp3c.category_name_param_3_count, 0) AS category_name_param_3_count,
  IFNULL(cnpc.category_name_price_count, 0) AS category_name_price_count,
  IFNULL(cnutc.category_name_user_type_count, 0) AS category_name_user_type_count,
  IFNULL(cacmdcc.city_all_categ_minmax_diff_count_count, 0) AS city_all_categ_minmax_diff_count_count,
  IFNULL(ccnc.city_category_name_count, 0) AS city_category_name_count,
  IFNULL(cc.city_count, 0) AS city_count,
  IFNULL(cddc.city_day_diff_count, 0) AS city_day_diff_count,
  IFNULL(cp1c.city_param_1_count, 0) AS city_param_1_count,
  IFNULL(cp2c.city_param_2_count, 0) AS city_param_2_count,
  IFNULL(cp3c.city_param_3_count, 0) AS city_param_3_count,
  IFNULL(cpcnc.city_parent_category_name_count, 0) AS city_parent_category_name_count,
  IFNULL(cpc.city_price_count, 0) AS city_price_count,
  IFNULL(cutc.city_user_type_count, 0) AS city_user_type_count,

  -- ここまで追加
  deal_probability
  
FROM
  `bqtest-114514.avito_features._3rd_feature_p1` AS t

-- ここから追加

LEFT OUTER JOIN
`avito._all_categ_minmax_diff_image_top_1_count` AS acmdit1c
ON
  t.all_categ_minmax_diff = acmdit1c.all_categ_minmax_diff
  AND t.image_top_1 = acmdit1c.image_top_1

LEFT OUTER JOIN
`avito._category_name_all_categ_minmax_diff_count` AS cnacmdc
ON
  t.all_categ_minmax_diff = cnacmdc.all_categ_minmax_diff
  AND t.category_name = cnacmdc.category_name

LEFT OUTER JOIN
`avito._category_name_count` AS cnc
ON
  t.category_name = cnc.category_name

LEFT OUTER JOIN
`avito._category_name_day_diff_count` AS cnddc
ON
  t.day_diff = cnddc.day_diff
  AND t.category_name = cnddc.category_name

LEFT OUTER JOIN
`avito._category_name_image_top_1_count` AS cnit1c
ON
  t.image_top_1 = cnit1c.image_top_1
  AND t.category_name = cnit1c.category_name

LEFT OUTER JOIN
`avito._category_name_param_1_count` AS cnp1c
ON
  t.param_1 = cnp1c.param_1
  AND t.category_name = cnp1c.category_name

LEFT OUTER JOIN
`avito._category_name_param_2_count` AS cnp2c
ON
  t.param_2 = cnp2c.param_2
  AND t.category_name = cnp2c.category_name


LEFT OUTER JOIN
`avito._category_name_param_3_count` AS cnp3c
ON
  t.param_3 = cnp3c.param_3
  AND t.category_name = cnp3c.category_name


LEFT OUTER JOIN
`avito._category_name_price_count` AS cnpc
ON
  t.price = cnpc.price
  AND t.category_name = cnpc.category_name

LEFT OUTER JOIN
`avito._category_name_user_type_count` AS cnutc
ON
  t.user_type = cnutc.user_type
  AND t.category_name = cnutc.category_name

LEFT OUTER JOIN
`avito._city_all_categ_minmax_diff_count_count` AS cacmdcc
ON
  t.all_categ_minmax_diff = cacmdcc.all_categ_minmax_diff
  AND t.city = cacmdcc.city


LEFT OUTER JOIN
`avito._city_category_name_count` AS ccnc
ON
  t.category_name = ccnc.category_name
  AND t.city = ccnc.city


LEFT OUTER JOIN
`avito._city_count` AS cc
ON t.city = cc.city


LEFT OUTER JOIN
`avito._city_day_diff_count` AS cddc
ON
  t.day_diff = cddc.day_diff
  AND t.city = cddc.city


LEFT OUTER JOIN
`avito._city_param_1_count` AS cp1c
ON
  t.param_1 = cp1c.param_1
  AND t.city = cp1c.city


LEFT OUTER JOIN
`avito._city_param_2_count` AS cp2c
ON
  t.param_2 = cp2c.param_2
  AND t.city = cp2c.city

LEFT OUTER JOIN
`avito._city_param_3_count` AS cp3c
ON
  t.param_3 = cp3c.param_3
  AND t.city = cp3c.city


LEFT OUTER JOIN
`avito._city_parent_category_name_count` AS cpcnc
ON
  t.parent_category_name = cpcnc.parent_category_name
  AND t.city = cpcnc.city


LEFT OUTER JOIN
`avito._city_price_count` AS cpc
ON
  t.price = cpc.price
  AND t.city = cpc.city


LEFT OUTER JOIN
`avito._city_user_type_count` AS cutc
ON
  t.user_type = cutc.user_type
  AND t.city = cutc.city



-- part 3
-- daydiff+その他脚を引っ張る特徴量を消去
-- 追加の特徴量を加えた

SELECT
  t.item_id,
  t.user_id,
  t.region,
  t.city,
  t.parent_category_name,
  t.category_name,
  t.param_1,
  t.param_2,
  t.param_3,
  t.user_type,
  t.price,
  t.day_diff,
  t.all_categ_minmax_diff,
  t.category_name_unique,
  t.all_category_count,
  t.city_unique,
  t.region_city_count,
  t.region_city_all_category_count,
  --t.user_id_all_category_count,
  --t.user_id_region_city_count,
  --t.user_id_region_city_parent_child_category_count,
  t.image_top_1,
  --t.user_id_price_count,
  --t.user_id_price_unique,
  t.all_categ_minmax_diff_image_top_1_count,
  t.category_name_all_categ_minmax_diff_count,
  t.category_name_count,
  --t.category_name_day_diff_count,
  t.category_name_image_top_1_count,
  --t.category_name_param_1_count,
  t.category_name_param_2_count,
  t.category_name_param_3_count,
  t.category_name_price_count,
  t.category_name_user_type_count,
  t.city_all_categ_minmax_diff_count_count,
  t.city_category_name_count,
  t.city_count,
  t.city_day_diff_count,
  t.city_param_1_count,
  --t.city_param_2_count,
  t.city_param_3_count,
  t.city_parent_category_name_count,
  t.city_price_count,
  t.city_user_type_count,
  -- ここから追加
  IFNULL(ddacmdc.day_diff_all_categ_minmax_diff_count, 0) AS day_diff_all_categ_minmax_diff_count,
  IFNULL(ddit1c.day_diff_image_top_1_count, 0) AS day_diff_image_top_1_count,
  IFNULL(it1c.image_top_1_count, 0) AS image_top_1_count,
  IFNULL(p1acmdc.param_1_all_categ_minmax_diff_count, 0) AS param_1_all_categ_minmax_diff_count,
  IFNULL(p1c.param_1_count, 0) AS param_1_count,
  IFNULL(p1ddc.param_1_day_diff_count, 0) AS param_1_day_diff_count,
  IFNULL(p1it1c.param_1_image_top_1_count, 0) AS param_1_image_top_1_count,
  IFNULL(p1p2c.param_1_param_2_count, 0) AS param_1_param_2_count,
  IFNULL(p1p3c.param_1_param_3_count, 0) AS param_1_param_3_count,
  IFNULL(p1pc.param_1_price_count, 0) AS param_1_price_count,
  IFNULL(p1utc.param_1_user_type_count, 0) AS param_1_user_type_count,
  IFNULL(p2c.param_2_count, 0) AS param_2_count,
  IFNULL(p2ddc.param_2_day_diff_count, 0) AS param_2_day_diff_count,
  IFNULL(p2it1c.param_2_image_top_1_count, 0) AS param_2_image_top_1_count,
  IFNULL(p2p3c.param_2_param_3_count, 0) AS param_2_param_3_count,
  IFNULL(p2pc.param_2_price_count, 0) AS param_2_price_count,
  IFNULL(p2utc.param_2_user_type_count, 0) AS param_2_user_type_count,
  IFNULL(p3acmdc.param_3_all_categ_minmax_diff_count, 0) AS param_3_all_categ_minmax_diff_count,
  IFNULL(p3c.param_3_count, 0) AS param_3_count,
  IFNULL(p3ddc.param_3_day_diff_count, 0) AS param_3_day_diff_count,
  IFNULL(p3it1c.param_3_image_top_1_count, 0) AS param_3_image_top_1_count,
  IFNULL(p3pc.param_3_price_count, 0) AS param_3_price_count,
  IFNULL(p3utc.param_3_user_type_count, 0) AS param_3_user_type_count,
  IFNULL(pcnacmdc.parent_category_name_all_categ_minmax_diff_count, 0) AS parent_category_name_all_categ_minmax_diff_count,
  IFNULL(pcnccnc.parent_category_name_child_category_name_count, 0) AS parent_category_name_child_category_name_count,
  IFNULL(pcnc.parent_category_name_count, 0) AS parent_category_name_count,
  IFNULL(pcnit1c.parent_category_name_image_top_1_count, 0) AS parent_category_name_image_top_1_count,
  IFNULL(pcnp1c.parent_category_name_param_1_count, 0) AS parent_category_name_param_1_count,
  IFNULL(pcnp2c.parent_category_name_param_2_count, 0) AS parent_category_name_param_2_count,
  IFNULL(pcnp3c.parent_category_name_param_3_count, 0) AS parent_category_name_param_3_count,
  IFNULL(pcnpc.parent_category_name_price_count, 0) AS parent_category_name_price_count,
  IFNULL(pcnutc.parent_category_name_user_type_count, 0) AS parent_category_name_user_type_count,
  pccu.category_name_unique AS parent_child_category_name_unique,
  IFNULL(pcp123c.parent_child_param_1_2_3_count, 0) AS parent_child_param_1_2_3_count,
  IFNULL(pacmdc.price_all_categ_minmax_diff_count, 0) AS price_all_categ_minmax_diff_count,
  IFNULL(pc.price_count, 0) AS price_count,
  IFNULL(pddc.price_day_diff_count, 0) AS price_day_diff_count,
  IFNULL(pit1c.price_image_top_1_count, 0) AS price_image_top_1_count,
  IFNULL(racmdc.region_all_categ_minmax_difff_count, 0) AS region_all_categ_minmax_difff_count,
  IFNULL(rccnc.region_child_category_name_count, 0) AS region_child_category_name_count,
  rcu.city_unique AS region_city_unique,
  IFNULL(rc.region_count, 0) AS region_count,
  IFNULL(rddc.region_day_diff_count, 0) AS region_day_diff_count,
  IFNULL(rit1c.region_image_top_1_count, 0) AS region_image_top_1_count,
  IFNULL(rp1c.region_param_1_count, 0) AS region_param_1_count,
  IFNULL(rp2c.region_param_2_count, 0) AS region_param_2_count,
  IFNULL(rp3c.region_param_3_count, 0) AS region_param_3_count,
  IFNULL(rpcnc.region_parent_category_name_count, 0) AS region_parent_category_name_count,
  IFNULL(rpc.region_price_count, 0) AS region_price_count,
  IFNULL(rutc.region_user_type_count, 0) AS region_user_type_count,
  IFNULL(uiacmdc.user_id_all_categ_minmax_diff_count, 0) AS user_id_all_categ_minmax_diff_count,
  IFNULL(uiccnc.user_id_child_category_name_count, 0) AS user_id_child_category_name_count,
  IFNULL(uicc.user_id_city_count, 0) AS user_id_city_count,
  IFNULL(uic.user_id_count, 0) AS user_id_count,
  IFNULL(uiddc.user_id_day_diff_count, 0) AS user_id_day_diff_count,
  IFNULL(uiit1c.user_id_image_top_1_count, 0) AS user_id_image_top_1_count,
  IFNULL(uip1c.user_id_param_1_count, 0) AS user_id_param_1_count,
  IFNULL(uip2c.user_id_param_2_count, 0) AS user_id_param_2_count,
  IFNULL(uip3c.user_id_param_3_count, 0) AS user_id_param_3_count,
  IFNULL(uipcnc.user_id_parent_category_name_count, 0) AS user_id_parent_category_name_count,
  IFNULL(uirc.user_id_region_count, 0) AS user_id_region_count,
  IFNULL(uiutc.user_id_user_type_count, 0) AS user_id_user_type_count,
  IFNULL(utacmdc.user_type_all_categ_minmax_diff_count, 0) AS user_type_all_categ_minmax_diff_count,
  IFNULL(utc.user_type_count, 0) AS user_type_count,
  IFNULL(utddc.user_type_day_diff_count, 0) AS user_type_day_diff_count,
  IFNULL(utit1c.user_type_image_top_1_count, 0) AS user_type_image_top_1_count,
  IFNULL(utpc.user_type_price_count, 0) AS user_type_price_count,
  -- ここまで追加
  deal_probability
  
FROM
  `bqtest-114514.avito_features._3rd_feature_p2` AS t

-- ここから追加

-- daydiffから続きやる．
LEFT OUTER JOIN
`avito._day_diff_all_categ_minmax_diff_count` AS ddacmdc
ON
  t.day_diff = ddacmdc.day_diff
  AND t.all_categ_minmax_diff = ddacmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._day_diff_image_top_1_count` AS ddit1c
ON
  t.day_diff = ddit1c.day_diff
  AND t.image_top_1 = ddit1c.image_top_1

LEFT OUTER JOIN
`avito._image_top_1_count` AS it1c
ON
  t.image_top_1 = it1c.image_top_1

LEFT OUTER JOIN
`avito._param_1_all_categ_minmax_diff_count` AS p1acmdc
ON
  t.param_1 = p1acmdc.param_1
  AND t.all_categ_minmax_diff = p1acmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._param_1_count` AS p1c
ON
  t.param_1 = p1c.param_1

LEFT OUTER JOIN
`avito._param_1_day_diff_count` AS p1ddc
ON
  t.param_1 = p1ddc.param_1
  AND t.day_diff = p1ddc.day_diff

LEFT OUTER JOIN
`avito._param_1_image_top_1_count` AS p1it1c
ON
  t.param_1 = p1it1c.param_1
  AND t.image_top_1 = p1it1c.image_top_1

LEFT OUTER JOIN
`avito._param_1_param_2_count` AS p1p2c
ON
  t.param_1 = p1p2c.param_1
  AND t.param_2 = p1p2c.param_2

LEFT OUTER JOIN
`avito._param_1_param_3_count` AS p1p3c
ON
  t.param_1 = p1p3c.param_1
  AND t.param_3 = p1p3c.param_3

LEFT OUTER JOIN
`avito._param_1_price_count` AS p1pc
ON
  t.param_1 = p1pc.param_1
  AND t.price = p1pc.price

LEFT OUTER JOIN
`avito._param_1_user_type_count` AS p1utc
ON
  t.param_1 = p1utc.param_1
  AND t.user_type = p1utc.user_type

LEFT OUTER JOIN
`avito._param_2_count` AS p2c
ON
  t.param_2 = p2c.param_2

LEFT OUTER JOIN
`avito._param_2_day_diff_count` AS p2ddc
ON
  t.param_2 = p2ddc.param_2
  AND t.day_diff = p2ddc.day_diff

LEFT OUTER JOIN
`avito._param_2_image_top_1_count` AS p2it1c
ON
  t.param_2 = p2it1c.param_2
  AND t.image_top_1 = p2it1c.image_top_1

LEFT OUTER JOIN
`avito._param_2_param_3_count` AS p2p3c
ON
  t.param_2 = p2p3c.param_2
  AND t.param_3 = p2p3c.param_3

LEFT OUTER JOIN
`avito._param_2_price_count` AS p2pc
ON
  t.param_2 = p2pc.param_2
  AND t.price = p2pc.price

LEFT OUTER JOIN
`avito._param_2_user_type_count` AS p2utc
ON
  t.param_2 = p2utc.param_2
  AND t.user_type = p2utc.user_type

LEFT OUTER JOIN
`avito._param_3_all_categ_minmax_diff_count` AS p3acmdc
ON
  t.param_3 = p3acmdc.param_3
  AND t.all_categ_minmax_diff = p3acmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._param_3_count` AS p3c
ON
  t.param_3 = p3c.param_3

LEFT OUTER JOIN
`avito._param_3_day_diff_count` AS p3ddc
ON
  t.param_3 = p3ddc.param_3
  AND t.day_diff = p3ddc.day_diff

LEFT OUTER JOIN
`avito._param_3_image_top_1_count` AS p3it1c
ON
  t.param_3 = p3it1c.param_3
  AND t.image_top_1 = p3it1c.image_top_1

LEFT OUTER JOIN
`avito._param_3_price_count` AS p3pc
ON
  t.param_3 = p3pc.param_3
  AND t.price = p3pc.price

LEFT OUTER JOIN
`avito._param_3_user_type_count` AS p3utc
ON
  t.param_3 = p3utc.param_3
  AND t.user_type = p3utc.user_type

LEFT OUTER JOIN
`avito._parent_category_name_all_categ_minmax_diff_count` AS pcnacmdc
ON
  t.parent_category_name = pcnacmdc.parent_category_name
  AND t.all_categ_minmax_diff = pcnacmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._parent_category_name_child_category_name_count` AS pcnccnc
ON
  t.parent_category_name = pcnccnc.parent_category_name
  AND t.category_name = pcnccnc.category_name

LEFT OUTER JOIN
`avito._parent_category_name_count` AS pcnc
ON
  t.parent_category_name = pcnc.parent_category_name

LEFT OUTER JOIN
`avito._parent_category_name_image_top_1_count` AS pcnit1c
ON
  t.parent_category_name = pcnit1c.parent_category_name
  AND t.image_top_1 = pcnit1c.image_top_1

LEFT OUTER JOIN
`avito._parent_category_name_param_1_count` AS pcnp1c
ON
  t.parent_category_name = pcnp1c.parent_category_name
  AND t.param_1 = pcnp1c.param_1

LEFT OUTER JOIN
`avito._parent_category_name_param_2_count` AS pcnp2c
ON
  t.parent_category_name = pcnp2c.parent_category_name
  AND t.param_2 = pcnp2c.param_2

LEFT OUTER JOIN
`avito._parent_category_name_param_3_count` AS pcnp3c
ON
  t.parent_category_name = pcnp3c.parent_category_name
  AND t.param_3 = pcnp3c.param_3

LEFT OUTER JOIN
`avito._parent_category_name_price_count` AS pcnpc
ON
  t.parent_category_name = pcnpc.parent_category_name
  AND t.price = pcnpc.price

LEFT OUTER JOIN
`avito._parent_category_name_user_type_count` AS pcnutc
ON
  t.parent_category_name = pcnutc.parent_category_name
  AND t.user_type = pcnutc.user_type

LEFT OUTER JOIN
`avito._parent_child_category_unique` AS pccu
ON
  t.parent_category_name = pccu.parent_category_name

LEFT OUTER JOIN
`avito._parent_child_param_1_2_3_count` AS pcp123c
ON
  t.parent_category_name = pcp123c.parent_category_name
  AND t.category_name = pcp123c.category_name
  AND t.param_1 = pcp123c.param_1
  AND t.param_2 = pcp123c.param_2
  AND t.param_3 = pcp123c.param_3


LEFT OUTER JOIN
`avito._price_all_categ_minmax_diff_count` AS pacmdc
ON
  t.price = pacmdc.price
  AND t.all_categ_minmax_diff = pacmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._price_count` AS pc
ON
  t.price = pc.price

LEFT OUTER JOIN
`avito._price_day_diff_count` AS pddc
ON
  t.price = pddc.price
  AND t.day_diff = pddc.day_diff

LEFT OUTER JOIN
`avito._price_image_top_1_count` AS pit1c
ON
  t.price = pit1c.price
  AND t.image_top_1 = pit1c.image_top_1

LEFT OUTER JOIN
`avito._region_all_categ_minmax_difff_count` AS racmdc
ON
  t.region = racmdc.region
  AND t.all_categ_minmax_diff = racmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._region_child_category_name_count` AS rccnc
ON
  t.region = rccnc.region
  AND t.category_name = rccnc.category_name

LEFT OUTER JOIN
`avito._region_city_unique` AS rcu
ON
  t.region = rcu.region

LEFT OUTER JOIN
`avito._region_count` AS rc
ON
  t.region = rc.region

LEFT OUTER JOIN
`avito._region_day_diff_count` AS rddc
ON
  t.region = rddc.region
  AND t.day_diff = rddc.day_diff

LEFT OUTER JOIN
`avito._region_image_top_1_count` AS rit1c
ON
  t.region = rit1c.region
  AND t.image_top_1 = rit1c.image_top_1

LEFT OUTER JOIN
`avito._region_param_1_count` AS rp1c
ON
  t.region = rp1c.region
  AND t.param_1 = rp1c.param_1

LEFT OUTER JOIN
`avito._region_param_2_count` AS rp2c
ON
  t.region = rp2c.region
  AND t.param_2 = rp2c.param_2

LEFT OUTER JOIN
`avito._region_param_3_count` AS rp3c
ON
  t.region = rp3c.region
  AND t.param_3 = rp3c.param_3

LEFT OUTER JOIN
`avito._region_parent_category_name_count` AS rpcnc
ON
  t.region = rpcnc.region
  AND t.parent_category_name = rpcnc.parent_category_name

LEFT OUTER JOIN
`avito._region_price_count` AS rpc
ON
  t.region = rpc.region
  AND t.price = rpc.price

LEFT OUTER JOIN
`avito._region_user_type_count` AS rutc
ON
  t.region = rutc.region
  AND t.user_type = rutc.user_type

LEFT OUTER JOIN
`avito._user_id_all_categ_minmax_diff_count` AS uiacmdc
ON
  t.user_id = uiacmdc.user_id
  AND t.all_categ_minmax_diff = uiacmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._user_id_child_category_name_count` AS uiccnc
ON
  t.user_id = uiccnc.user_id
  AND t.category_name = uiccnc.category_name

LEFT OUTER JOIN
`avito._user_id_city_count` AS uicc
ON
  t.user_id = uicc.user_id
  AND t.city = uicc.city

LEFT OUTER JOIN
`avito._user_id_count` AS uic
ON
  t.user_id = uic.user_id

LEFT OUTER JOIN
`avito._user_id_day_diff_count` AS uiddc
ON
  t.user_id = uiddc.user_id
  AND t.day_diff = uiddc.day_diff

LEFT OUTER JOIN
`avito._user_id_image_top_1_count` AS uiit1c
ON
  t.user_id = uiit1c.user_id
  AND t.image_top_1 = uiit1c.image_top_1

LEFT OUTER JOIN
`avito._user_id_param_1_count` AS uip1c
ON
  t.user_id = uip1c.user_id
  AND t.param_1 = uip1c.param_1

LEFT OUTER JOIN
`avito._user_id_param_2_count` AS uip2c
ON
  t.user_id = uip2c.user_id
  AND t.param_2 = uip2c.param_2

LEFT OUTER JOIN
`avito._user_id_param_3_count` AS uip3c
ON
  t.user_id = uip3c.user_id
  AND t.param_3 = uip3c.param_3

LEFT OUTER JOIN
`avito._user_id_parent_category_name_count` AS uipcnc
ON
  t.user_id = uipcnc.user_id
  AND t.parent_category_name = uipcnc.parent_category_name

LEFT OUTER JOIN
`avito._user_id_region_count` AS uirc
ON
  t.user_id = uirc.user_id
  AND t.region = uirc.region

LEFT OUTER JOIN
`avito._user_id_user_type_count` AS uiutc
ON
  t.user_id = uiutc.user_id
  AND t.user_type = uiutc.user_type

---
LEFT OUTER JOIN
`avito._user_type_all_categ_minmax_diff_count` AS utacmdc
ON
  t.user_type = utacmdc.user_type
  AND t.all_categ_minmax_diff = utacmdc.all_categ_minmax_diff

LEFT OUTER JOIN
`avito._user_type_count` AS utc
ON
  t.user_type = utc.user_type

LEFT OUTER JOIN
`avito._user_type_day_diff_count` AS utddc
ON
  t.user_type = utddc.user_type
  AND t.day_diff = utddc.day_diff

LEFT OUTER JOIN
`avito._user_type_image_top_1_count` AS utit1c
ON
  t.user_type = utit1c.user_type
  AND t.image_top_1 = utit1c.image_top_1

LEFT OUTER JOIN
`avito._user_type_price_count` AS utpc
ON
  t.user_type = utpc.user_type
  AND t.price = utpc.price




-- part 4
-- minmax_diffの追加
-- ベースは_3rd_feature_p3

-- 元となる特徴量作成用クエリのテンプレ
--SELECT <variable>, count(1) as cnt, TIMESTAMP_DIFF(MAX(TIMESTAMP(activation_date)), MIN(TIMESTAMP(activation_date)), DAY) as <variable>_minmax_diff 
--FROM `bqtest-114514.avito.train_test` group by <variable>

--PART 1
-- dstination table: _4th_feature_tmp
SELECT
  t.*,
  -- ここから追加
  IFNULL(cnmd.category_name_minmax_diff, -1) AS category_name_minmax_diff,
  IFNULL(cmd.city_minmax_diff, -1) AS city_minmax_diff,
  IFNULL(it1md.image_top_1_minmax_diff, -1) AS image_top_1_minmax_diff,
  IFNULL(p1md.param_1_minmax_diff, -1) AS param_1_minmax_diff,
  IFNULL(p2md.param_2_minmax_diff, -1) AS param_2_minmax_diff,
  IFNULL(p3md.param_3_minmax_diff, -1) AS param_3_minmax_diff,
  IFNULL(pcnmd.parent_category_name_minmax_diff, -1) AS parent_category_name_minmax_diff,
  IFNULL(pmd.price_minmax_diff, -1) AS price_minmax_diff,
  IFNULL(rmd.region_minmax_diff, -1) AS region_minmax_diff,
  IFNULL(uimd.user_id_minmax_diff, -1) AS user_id_minmax_diff,
  IFNULL(utmd.user_type_minmax_diff, -1) AS user_type_minmax_diff
  -- ここまで追加
  
FROM
  `bqtest-114514.avito_features._3rd_feature_p3` AS t

-- ここから追加
LEFT OUTER JOIN
`avito_4th.category_name_minmax_diff` AS cnmd
ON
  t.category_name = cnmd.category_name

LEFT OUTER JOIN
`avito_4th.city_minmax_diff` AS cmd
ON
  t.city = cmd.city

LEFT OUTER JOIN
`avito_4th.image_top_1_minmax_diff` AS it1md
ON
  t.image_top_1 = it1md.image_top_1

LEFT OUTER JOIN
`avito_4th.param_1_minmax_diff` AS p1md
ON
  t.param_1 = p1md.param_1

LEFT OUTER JOIN
`avito_4th.param_2_minmax_diff` AS p2md
ON
  t.param_2 = p2md.param_2

LEFT OUTER JOIN
`avito_4th.param_3_minmax_diff` AS p3md
ON
  t.param_3 = p3md.param_3

LEFT OUTER JOIN
`avito_4th.parent_category_name_minmax_diff` AS pcnmd
ON
  t.parent_category_name = pcnmd.parent_category_name

LEFT OUTER JOIN
`avito_4th.price_minmax_diff` AS pmd
ON
  t.price = pmd.price

LEFT OUTER JOIN
`avito_4th.region_minmax_diff` AS rmd
ON
  t.region = rmd.region

LEFT OUTER JOIN
`avito_4th.user_id_minmax_diff` AS uimd
ON
  t.user_id = uimd.user_id

LEFT OUTER JOIN
`avito_4th.user_type_minmax_diff` AS utmd
ON
  t.user_type = utmd.user_type


--PART2
--destination table: _4th_feature
SELECT
  item_id,	
  user_id,	
  region,	
  city,	
  parent_category_name,	
  category_name,	
  param_1,	
  param_2,	
  param_3,	
  user_type,	
  price,
  image_top_1,
  all_categ_minmax_diff,	
  category_name_unique,	
  all_category_count,	
  city_unique,	
  region_city_count,	
  region_city_all_category_count,	
  all_categ_minmax_diff_image_top_1_count,	
  category_name_all_categ_minmax_diff_count,	
  category_name_count,	
  category_name_image_top_1_count,	
  category_name_param_2_count,	
  category_name_param_3_count,	
  category_name_price_count,	
  category_name_user_type_count,	
  city_all_categ_minmax_diff_count_count,	
  city_category_name_count,	
  city_count,		
  city_param_1_count,	
  city_param_3_count,	
  city_parent_category_name_count,	
  city_price_count,	
  city_user_type_count,	
  image_top_1_count,	
  param_1_all_categ_minmax_diff_count,	
  param_1_count,	
  param_1_image_top_1_count,	
  param_1_param_2_count,	
  param_1_param_3_count,	
  param_1_price_count,	
  param_1_user_type_count,	
  param_2_count,	
  param_2_image_top_1_count,	
  param_2_param_3_count,	
  param_2_price_count,	
  param_2_user_type_count,	
  param_3_all_categ_minmax_diff_count,	
  param_3_count,	
  param_3_image_top_1_count,	
  param_3_price_count,	
  param_3_user_type_count,	
  parent_category_name_all_categ_minmax_diff_count,	
  parent_category_name_child_category_name_count,	
  parent_category_name_count,	
  parent_category_name_image_top_1_count,	
  parent_category_name_param_1_count,	
  parent_category_name_param_2_count,	
  parent_category_name_param_3_count,	
  parent_category_name_price_count,	
  parent_category_name_user_type_count,	
  parent_child_category_name_unique,	
  parent_child_param_1_2_3_count,	
  price_all_categ_minmax_diff_count,	
  price_count,	
  price_image_top_1_count,	
  region_all_categ_minmax_difff_count,	
  region_child_category_name_count,	
  region_city_unique,	
  region_count,	
  region_image_top_1_count,	
  region_param_1_count,	
  region_param_2_count,	
  region_param_3_count,	
  region_parent_category_name_count,	
  region_price_count,	
  region_user_type_count,	
  user_id_all_categ_minmax_diff_count,	
  user_id_child_category_name_count,	
  user_id_city_count,	
  user_id_count,	
  user_id_image_top_1_count,	
  user_id_param_1_count,	
  user_id_param_2_count,	
  user_id_param_3_count,	
  user_id_parent_category_name_count,	
  user_id_region_count,	
  user_id_user_type_count,	
  user_type_all_categ_minmax_diff_count,	
  user_type_count,	
  user_type_image_top_1_count,	
  user_type_price_count,	
  category_name_minmax_diff,
  city_minmax_diff,
  image_top_1_minmax_diff,	
  param_1_minmax_diff,	
  param_2_minmax_diff,	
  param_3_minmax_diff,	
  parent_category_name_minmax_diff,	
  price_minmax_diff,	
  region_minmax_diff,	
  user_id_minmax_diff,	
  user_type_minmax_diff,	
  deal_probability
FROM
  `bqtest-114514.avito_4th._4th_feature_tmp` 


-- 第五段階
-- Gain上位の元ネタ変数を3つ以上組み合わせて特徴量を作る：
  -- カウント変数，ユニーク変数，minmax_diff

-- ユニーク変数，minmax_diffの作り方
SELECT
  <feature_1>,
  <feature_2>,
  count(distinct <feature_3>) as uq,
  TIMESTAMP_DIFF(MAX(TIMESTAMP(activation_date)), MIN(TIMESTAMP(activation_date)), DAY) AS minmax_diff
  
FROM
  `bqtest-114514.avito.train_test`
GROUP BY
  <feature_1>,
  <feature_2>


--dst: _5th_feature
SELECT
  t.*,

  -- ここから追加
  IFNULL(c1.cnt, 0) AS category_name_price_image_top_1_count,
  IFNULL(c2.cnt, 0) AS city_category_name_image_top_1_count,
  IFNULL(c3.cnt, 0) AS city_category_name_price_count,
  IFNULL(c4.cnt, 0) AS city_param_1_category_name_count,
  IFNULL(c5.cnt, 0) AS city_param_1_image_top_1_count,
  IFNULL(c6.cnt, 0) AS city_param_1_param_2_count,
  IFNULL(c7.cnt, 0) AS city_param_1_param_3_count,
  IFNULL(c8.cnt, 0) AS city_param_1_price_count,
  IFNULL(c9.cnt, 0) AS city_param_2_category_name_count,
  IFNULL(c10.cnt, 0) AS city_param_2_image_top_1_count,
  IFNULL(c11.cnt, 0) AS city_param_2_param_3_count,
  IFNULL(c12.cnt, 0) AS city_param_2_price_count,
  IFNULL(c13.cnt, 0) AS city_param_3_category_name_count,
  IFNULL(c14.cnt, 0) AS city_param_3_image_top_1_count,
  IFNULL(c15.cnt, 0) AS city_param_3_price_count,
  IFNULL(c16.cnt, 0) AS city_price_image_top_1_count,
  IFNULL(c17.cnt, 0) AS param_1_category_name_image_top_1_count,
  IFNULL(c18.cnt, 0) AS param_1_category_name_price_count,
  IFNULL(c19.cnt, 0) AS param_1_param_2_category_name_count,
  IFNULL(c20.cnt, 0) AS param_1_param_2_image_top_1_count,
  IFNULL(c21.cnt, 0) AS param_1_param_2_param_3_count,
  IFNULL(c22.cnt, 0) AS param_1_param_2_price_count,
  IFNULL(c23.cnt, 0) AS param_1_param_3_category_name_count,
  IFNULL(c24.cnt, 0) AS param_1_param_3_image_top_1_count,
  IFNULL(c25.cnt, 0) AS param_1_param_3_price_count,
  IFNULL(c26.cnt, 0) AS param_2_category_name_image_top_1_count,
  IFNULL(c27.cnt, 0) AS param_2_category_name_price_count,
  IFNULL(c28.cnt, 0) AS param_2_param_3_category_name_count,
  IFNULL(c29.cnt, 0) AS param_2_param_3_image_top_1_count,
  IFNULL(c30.cnt, 0) AS param_2_param_3_price_count,
  IFNULL(c31.cnt, 0) AS param_2_price_image_top_1_count,
  IFNULL(c32.cnt, 0) AS param_3_category_name_image_top_1_count,
  IFNULL(c33.cnt, 0) AS param_3_category_name_price_count,
  IFNULL(c34.cnt, 0) AS param_3_price_image_top_1_count,
  IFNULL(c35.cnt, 0) AS user_id_category_name_image_top_1_count,
  IFNULL(c36.cnt, 0) AS user_id_city_category_name_count,
  IFNULL(c37.cnt, 0) AS user_id_city_image_top_1_count,
  IFNULL(c38.cnt, 0) AS user_id_city_param_1_count,
  IFNULL(c39.cnt, 0) AS user_id_city_param_2_count,
  IFNULL(c40.cnt, 0) AS user_id_city_param_3_count,
  IFNULL(c41.cnt, 0) AS user_id_city_price_count,
  IFNULL(c42.cnt, 0) AS user_id_param_1_category_name_count,
  IFNULL(c43.cnt, 0) AS user_id_param_1_image_top_1_count,
  IFNULL(c44.cnt, 0) AS user_id_param_1_param_2_count,
  IFNULL(c45.cnt, 0) AS user_id_param_1_param_3_count,
  IFNULL(c46.cnt, 0) AS user_id_param_1_price_count,
  IFNULL(c47.cnt, 0) AS user_id_param_2_category_name_count,
  IFNULL(c48.cnt, 0) AS user_id_param_2_image_top_1_count,
  IFNULL(c49.cnt, 0) AS user_id_param_2_param_3_count,
  IFNULL(c50.cnt, 0) AS user_id_param_2_price_count,
  IFNULL(c51.cnt, 0) AS user_id_param_3_category_name_count,
  IFNULL(c52.cnt, 0) AS user_id_param_3_image_top_1_count,
  IFNULL(c53.cnt, 0) AS user_id_param_3_price_count,
  IFNULL(c54.cnt, 0) AS user_id_price_image_top_1_count,

  IFNULL(uqmmd1.minmax_diff, 0) AS category_name_price_image_top_1_minmax_diff,
  IFNULL(uqmmd2.minmax_diff, 0) AS city_category_name_image_top_1_minmax_diff,
  IFNULL(uqmmd3.minmax_diff, 0) AS city_category_name_price_minmax_diff,
  IFNULL(uqmmd4.minmax_diff, 0) AS city_param_1_category_name_minmax_diff,
  IFNULL(uqmmd5.minmax_diff, 0) AS city_param_1_image_top_1_minmax_diff,
  IFNULL(uqmmd6.minmax_diff, 0) AS city_param_1_param_2_minmax_diff,
  IFNULL(uqmmd7.minmax_diff, 0) AS city_param_1_param_3_minmax_diff,
  IFNULL(uqmmd8.minmax_diff, 0) AS city_param_1_price_minmax_diff,
  IFNULL(uqmmd9.minmax_diff, 0) AS city_param_2_category_name_minmax_diff,
  IFNULL(uqmmd10.minmax_diff, 0) AS city_param_2_image_top_1_minmax_diff,
  IFNULL(uqmmd11.minmax_diff, 0) AS city_param_2_param_3_minmax_diff,
  IFNULL(uqmmd12.minmax_diff, 0) AS city_param_2_price_minmax_diff,
  IFNULL(uqmmd13.minmax_diff, 0) AS city_param_3_category_name_minmax_diff,
  IFNULL(uqmmd14.minmax_diff, 0) AS city_param_3_image_top_1_minmax_diff,
  IFNULL(uqmmd15.minmax_diff, 0) AS city_price_image_top_1_minmax_diff,
  IFNULL(uqmmd16.minmax_diff, 0) AS param_1_category_name_image_top_1_minmax_diff,
  IFNULL(uqmmd17.minmax_diff, 0) AS param_1_category_name_price_minmax_diff,
  IFNULL(uqmmd18.minmax_diff, 0) AS param_1_param_2_category_name_minmax_diff,
  IFNULL(uqmmd19.minmax_diff, 0) AS param_1_param_2_image_top_1_minmax_diff,
  IFNULL(uqmmd20.minmax_diff, 0) AS param_1_param_2_param_3_minmax_diff,
  IFNULL(uqmmd21.minmax_diff, 0) AS param_1_param_2_price_minmax_diff,
  IFNULL(uqmmd22.minmax_diff, 0) AS param_1_param_3_category_name_minmax_diff,
  IFNULL(uqmmd23.minmax_diff, 0) AS param_1_param_3_image_top_1_minmax_diff,
  IFNULL(uqmmd24.minmax_diff, 0) AS param_1_param_3_price_minmax_diff,
  IFNULL(uqmmd25.minmax_diff, 0) AS param_1_price_image_top_1_diff,
  IFNULL(uqmmd26.minmax_diff, 0) AS param_2_category_name_image_top_1_minmax_diff,
  IFNULL(uqmmd27.minmax_diff, 0) AS param_2_category_name_price_diff,
  IFNULL(uqmmd28.minmax_diff, 0) AS param_2_param_3_image_top_1_minmax_diff,
  IFNULL(uqmmd29.minmax_diff, 0) AS param_2_param_3_price_minmax_diff,
  IFNULL(uqmmd30.minmax_diff, 0) AS param_2_price_image_top_1_minmax_diff,
  IFNULL(uqmmd31.minmax_diff, 0) AS param_3_category_name_image_top_1_minmax_diff,
  IFNULL(uqmmd32.minmax_diff, 0) AS param_3_category_name_price_minmax_diff,
  IFNULL(uqmmd33.minmax_diff, 0) AS param_3_price_image_top_1_minmax_diff,
  IFNULL(uqmmd34.minmax_diff, 0) AS user_id_category_name_image_top_1_minmax_diff,
  IFNULL(uqmmd35.minmax_diff, 0) AS user_id_category_name_price_minmax_diff,
  IFNULL(uqmmd36.minmax_diff, 0) AS user_id_city_category_name_minmax_diff,
  IFNULL(uqmmd37.minmax_diff, 0) AS user_id_city_image_top_1_minmax_diff,
  IFNULL(uqmmd38.minmax_diff, 0) AS user_id_city_param_1_minmax_diff,
  IFNULL(uqmmd39.minmax_diff, 0) AS user_id_city_param_2_minmax_diff,
  IFNULL(uqmmd40.minmax_diff, 0) AS user_id_city_param_3_minmax_diff,
  IFNULL(uqmmd41.minmax_diff, 0) AS user_id_city_price_minmax_diff,
  IFNULL(uqmmd42.minmax_diff, 0) AS user_id_param_1_category_name_minmax_diff,
  IFNULL(uqmmd43.minmax_diff, 0) AS user_id_param_1_image_top_1_minmax_diff,
  IFNULL(uqmmd44.minmax_diff, 0) AS user_id_param_1_param_2_minmax_diff,
  IFNULL(uqmmd45.minmax_diff, 0) AS user_id_param_1_param_3_minmax_diff,
  IFNULL(uqmmd46.minmax_diff, 0) AS user_id_param_1_price_minmax_diff,
  IFNULL(uqmmd47.minmax_diff, 0) AS user_id_param_2_category_name_minmax_diff,
  IFNULL(uqmmd48.minmax_diff, 0) AS user_id_param_2_image_top_1_minmax_diff,
  IFNULL(uqmmd49.minmax_diff, 0) AS user_id_param_2_param_3_minmax_diff,
  IFNULL(uqmmd50.minmax_diff, 0) AS user_id_param_2_price_minmax_diff,
  IFNULL(uqmmd51.minmax_diff, 0) AS user_id_param_3_category_name_minmax_diff,
  IFNULL(uqmmd52.minmax_diff, 0) AS user_id_param_3_image_top_1_minmax_diff,
  IFNULL(uqmmd53.minmax_diff, 0) AS user_id_param_3_price_minmax_diff,
  IFNULL(uqmmd54.minmax_diff, 0) AS user_id_price_image_top_1_minmax_diff,

  IFNULL(uqmmd1.uq, 0) AS category_name_price_image_top_1_uq,
  IFNULL(uqmmd2.uq, 0) AS city_category_name_image_top_1_uq,
  IFNULL(uqmmd3.uq, 0) AS city_category_name_price_uq,
  IFNULL(uqmmd4.uq, 0) AS city_param_1_category_name_uq,
  IFNULL(uqmmd5.uq, 0) AS city_param_1_image_top_1_uq,
  IFNULL(uqmmd6.uq, 0) AS city_param_1_param_2_uq,
  IFNULL(uqmmd7.uq, 0) AS city_param_1_param_3_uq,
  IFNULL(uqmmd8.uq, 0) AS city_param_1_price_uq,
  IFNULL(uqmmd9.uq, 0) AS city_param_2_category_name_uq,
  IFNULL(uqmmd10.uq, 0) AS city_param_2_image_top_1_uq,
  IFNULL(uqmmd11.uq, 0) AS city_param_2_param_3_uq,
  IFNULL(uqmmd12.uq, 0) AS city_param_2_price_uq,
  IFNULL(uqmmd13.uq, 0) AS city_param_3_category_name_uq,
  IFNULL(uqmmd14.uq, 0) AS city_param_3_image_top_1_uq,
  IFNULL(uqmmd15.uq, 0) AS city_price_image_top_1_uq,
  IFNULL(uqmmd16.uq, 0) AS param_1_category_name_image_top_1_uq,
  IFNULL(uqmmd17.uq, 0) AS param_1_category_name_price_uq,
  IFNULL(uqmmd18.uq, 0) AS param_1_param_2_category_name_uq,
  IFNULL(uqmmd19.uq, 0) AS param_1_param_2_image_top_1_uq,
  IFNULL(uqmmd20.uq, 0) AS param_1_param_2_param_3_uq,
  IFNULL(uqmmd21.uq, 0) AS param_1_param_2_price_uq,
  IFNULL(uqmmd22.uq, 0) AS param_1_param_3_category_name_uq,
  IFNULL(uqmmd23.uq, 0) AS param_1_param_3_image_top_1_uq,
  IFNULL(uqmmd24.uq, 0) AS param_1_param_3_price_uq,
  IFNULL(uqmmd25.uq, 0) AS param_1_price_image_top_1_uq,
  IFNULL(uqmmd26.uq, 0) AS param_2_category_name_image_top_1_uq,
  IFNULL(uqmmd27.uq, 0) AS param_2_category_name_price_uq,
  IFNULL(uqmmd28.uq, 0) AS param_2_param_3_image_top_1_uq,
  IFNULL(uqmmd29.uq, 0) AS param_2_param_3_price_uq,
  IFNULL(uqmmd30.uq, 0) AS param_2_price_image_top_1_uq,
  IFNULL(uqmmd31.uq, 0) AS param_3_category_name_image_top_1_uq,
  IFNULL(uqmmd32.uq, 0) AS param_3_category_name_price_uq,
  IFNULL(uqmmd33.uq, 0) AS param_3_price_image_top_1_uq,
  IFNULL(uqmmd34.uq, 0) AS user_id_category_name_image_top_1_uq,
  IFNULL(uqmmd35.uq, 0) AS user_id_category_name_price_uq,
  IFNULL(uqmmd36.uq, 0) AS user_id_city_category_name_uq,
  IFNULL(uqmmd37.uq, 0) AS user_id_city_image_top_1_uq,
  IFNULL(uqmmd38.uq, 0) AS user_id_city_param_1_uq,
  IFNULL(uqmmd39.uq, 0) AS user_id_city_param_2_uq,
  IFNULL(uqmmd40.uq, 0) AS user_id_city_param_3_uq,
  IFNULL(uqmmd41.uq, 0) AS user_id_city_price_uq,
  IFNULL(uqmmd42.uq, 0) AS user_id_param_1_category_name_uq,
  IFNULL(uqmmd43.uq, 0) AS user_id_param_1_image_top_1_uq,
  IFNULL(uqmmd44.uq, 0) AS user_id_param_1_param_2_uq,
  IFNULL(uqmmd45.uq, 0) AS user_id_param_1_param_3_uq,
  IFNULL(uqmmd46.uq, 0) AS user_id_param_1_price_uq,
  IFNULL(uqmmd47.uq, 0) AS user_id_param_2_category_name_uq,
  IFNULL(uqmmd48.uq, 0) AS user_id_param_2_image_top_1_uq,
  IFNULL(uqmmd49.uq, 0) AS user_id_param_2_param_3_uq,
  IFNULL(uqmmd50.uq, 0) AS user_id_param_2_price_uq,
  IFNULL(uqmmd51.uq, 0) AS user_id_param_3_category_name_uq,
  IFNULL(uqmmd52.uq, 0) AS user_id_param_3_image_top_1_uq,
  IFNULL(uqmmd53.uq, 0) AS user_id_param_3_price_uq,
  IFNULL(uqmmd54.uq, 0) AS user_id_price_image_top_1_uq

  
FROM
  `bqtest-114514.avito_4th._4th_feature_wo_fillna_minus` AS t

-- ここから追加
LEFT OUTER JOIN
`avito_5th.category_name_price_image_top_1_cnt` AS c1
ON
  t.category_name = c1.category_name
  AND t.price = c1.price
  AND t.image_top_1 = c1.image_top_1


LEFT OUTER JOIN
`avito_5th.city_category_name_image_top_1_cnt` AS c2
ON
  t.city = c2.city
  AND t.category_name = c2.category_name
  AND t.image_top_1 = c2.image_top_1

  LEFT OUTER JOIN
`avito_5th.city_category_name_price_cnt` AS c3
ON
  t.city = c3.city
  AND t.category_name = c3.category_name
  AND t.price = c3.price

  LEFT OUTER JOIN
`avito_5th.city_param_1_category_name_cnt` AS c4
ON
  t.city = c4.city
  AND t.param_1 = c4.param_1
  AND t.category_name = c4.category_name

  LEFT OUTER JOIN
`avito_5th.city_param_1_image_top_1_cnt` AS c5
ON
  t.city = c5.city
  AND t.param_1 = c5.param_1
  AND t.image_top_1 = c5.image_top_1

  LEFT OUTER JOIN
`avito_5th.city_param_1_param_2_cnt` AS c6
ON
  t.city = c6.city
  AND t.param_1 = c6.param_1
  AND t.param_2 = c6.param_2

  LEFT OUTER JOIN
`avito_5th.city_param_1_param_3_cnt` AS c7
ON
  t.city = c7.city
  AND t.param_1 = c7.param_1
  AND t.param_3 = c7.param_3

  LEFT OUTER JOIN
`avito_5th.city_param_1_price_cnt` AS c8
ON
  t.city = c8.city
  AND t.param_1 = c8.param_1
  AND t.price = c8.price

  LEFT OUTER JOIN
`avito_5th.city_param_2_category_name_cnt` AS c9
ON
  t.city = c9.city
  AND t.param_2 = c9.param_2
  AND t.category_name = c9.category_name

  LEFT OUTER JOIN
`avito_5th.city_param_2_image_top_1_cnt` AS c10
ON
  t.city = c10.city
  AND t.param_2 = c10.param_2
  AND t.image_top_1 = c10.image_top_1

  LEFT OUTER JOIN
`avito_5th.city_param_2_param_3_cnt` AS c11
ON
  t.city = c11.city
  AND t.param_2 = c11.param_2
  AND t.param_3 = c11.param_3

  LEFT OUTER JOIN
`avito_5th.city_param_2_price_cnt` AS c12
ON
  t.city = c12.city
  AND t.param_2 = c12.param_2
  AND t.price = c12.price

  LEFT OUTER JOIN
`avito_5th.city_param_3_category_name_cnt` AS c13
ON
  t.city = c13.city
  AND t.param_3 = c13.param_3
  AND t.category_name = c13.category_name

  LEFT OUTER JOIN
`avito_5th.city_param_3_image_top_1_cnt` AS c14
ON
  t.city = c14.city
  AND t.param_3 = c14.param_3
  AND t.image_top_1 = c14.image_top_1

  LEFT OUTER JOIN
`avito_5th.city_param_3_price_cnt` AS c15
ON
  t.city = c15.city
  AND t.param_3 = c15.param_3
  AND t.price = c15.price

  LEFT OUTER JOIN
`avito_5th.city_price_image_top_1_cnt` AS c16
ON
  t.city = c16.city
  AND t.price = c16.price
  AND t.image_top_1 = c16.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_1_category_name_image_top_1_cnt` AS c17
ON
  t.param_1 = c17.param_1
  AND t.category_name = c17.category_name
  AND t.image_top_1 = c17.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_1_category_name_price_cnt` AS c18
ON
  t.param_1 = c18.param_1
  AND t.category_name = c18.category_name
  AND t.price = c18.price

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_category_name_cnt` AS c19
ON
  t.param_1 = c19.param_1
  AND t.param_2 = c19.param_2
  AND t.category_name = c19.category_name

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_image_top_1_cnt` AS c20
ON
  t.param_1 = c20.param_1
  AND t.param_2 = c20.param_2
  AND t.image_top_1 = c20.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_param_3_cnt` AS c21
ON
  t.param_1 = c21.param_1
  AND t.param_2 = c21.param_2
  AND t.param_3 = c21.param_3

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_price_cnt` AS c22
ON
  t.param_1 = c22.param_1
  AND t.param_2 = c22.param_2
  AND t.price = c22.price

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_category_name_cnt` AS c23
ON
  t.param_1 = c23.param_1
  AND t.param_3 = c23.param_3
  AND t.category_name = c23.category_name

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_image_top_1_cnt` AS c24
ON
  t.param_1 = c24.param_1
  AND t.param_3 = c24.param_3
  AND t.image_top_1 = c24.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_price_cnt` AS c25
ON
  t.param_1 = c25.param_1
  AND t.param_3 = c25.param_3
  AND t.price = c25.price

  LEFT OUTER JOIN
`avito_5th.param_2_category_name_image_top_1_cnt` AS c26
ON
  t.param_2 = c26.param_2
  AND t.category_name = c26.category_name
  AND t.image_top_1 = c26.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_2_category_name_price_cnt` AS c27
ON
  t.param_2 = c27.param_2
  AND t.category_name = c27.category_name
  AND t.price = c27.price

  LEFT OUTER JOIN
`avito_5th.param_2_param_3_category_name_cnt` AS c28
ON
  t.param_2 = c28.param_2
  AND t.param_3 = c28.param_3
  AND t.category_name = c28.category_name

  LEFT OUTER JOIN
`avito_5th.param_2_param_3_image_top_1_cnt` AS c29
ON
  t.param_2 = c29.param_2
  AND t.param_3 = c29.param_3
  AND t.image_top_1 = c29.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_2_param_3_price_cnt` AS c30
ON
  t.param_2 = c30.param_2
  AND t.param_3 = c30.param_3
  AND t.price = c30.price

  LEFT OUTER JOIN
`avito_5th.param_2_price_image_top_1_cnt` AS c31
ON
  t.param_2 = c31.param_2
  AND t.price = c31.price
  AND t.image_top_1 = c31.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_3_category_name_image_top_1_cnt` AS c32
ON
  t.param_3 = c32.param_3
  AND t.category_name = c32.category_name
  AND t.image_top_1 = c32.image_top_1

  LEFT OUTER JOIN
`avito_5th.param_3_category_name_price_cnt` AS c33
ON
  t.param_3 = c33.param_3
  AND t.category_name = c33.category_name
  AND t.price = c33.price

  LEFT OUTER JOIN
`avito_5th.param_3_price_image_top_1_cnt` AS c34
ON
  t.param_3 = c34.param_3
  AND t.price = c34.price
  AND t.image_top_1 = c34.image_top_1

  LEFT OUTER JOIN
`avito_5th.user_id_category_name_image_top_1_cnt` AS c35
ON
  t.user_id = c35.user_id
  AND t.category_name = c35.category_name
  AND t.image_top_1 = c35.image_top_1

  LEFT OUTER JOIN
`avito_5th.user_id_city_category_name_cnt` AS c36
ON
  t.user_id = c36.user_id
  AND t.city = c36.city
  AND t.category_name = c36.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_city_image_top_1_cnt` AS c37
ON
  t.user_id = c37.user_id
  AND t.city = c37.city
  AND t.image_top_1 = c37.image_top_1

  LEFT OUTER JOIN
`avito_5th.user_id_city_param_1_cnt` AS c38
ON
  t.user_id = c38.user_id
  AND t.city = c38.city
  AND t.param_1 = c38.param_1

    LEFT OUTER JOIN
`avito_5th.user_id_city_param_2_cnt` AS c39
ON
  t.user_id = c39.user_id
  AND t.city = c39.city
  AND t.param_2 = c39.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_city_param_3_cnt` AS c40
ON
  t.user_id = c40.user_id
  AND t.city = c40.city
  AND t.param_3 = c40.param_3

  LEFT OUTER JOIN
`avito_5th.user_id_city_price_cnt` AS c41
ON
  t.user_id = c41.user_id
  AND t.city = c41.city
  AND t.price = c41.price

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_category_name_cnt` AS c42
ON
  t.user_id = c42.user_id
  AND t.param_1 = c42.param_1
  AND t.category_name = c42.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_image_top_1_cnt` AS c43
ON
  t.user_id = c43.user_id
  AND t.param_1 = c43.param_1
  AND t.image_top_1 = c43.image_top_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_param_2_cnt` AS c44
ON
  t.user_id = c44.user_id
  AND t.param_1 = c44.param_1
  AND t.param_2 = c44.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_param_3_cnt` AS c45
ON
  t.user_id = c45.user_id
  AND t.param_1 = c45.param_1
  AND t.param_3 = c45.param_3


  LEFT OUTER JOIN
`avito_5th.user_id_param_1_price_cnt` AS c46
ON
  t.user_id = c46.user_id
  AND t.param_1 = c46.param_1
  AND t.price = c46.price

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_category_name_cnt` AS c47
ON
  t.user_id = c47.user_id
  AND t.param_2 = c47.param_2
  AND t.category_name = c47.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_image_top_1_cnt` AS c48
ON
  t.user_id = c48.user_id
  AND t.param_2 = c48.param_2
  AND t.image_top_1 = c48.image_top_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_param_3_cnt` AS c49
ON
  t.user_id = c49.user_id
  AND t.param_2 = c49.param_2
  AND t.param_3 = c49.param_3

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_price_cnt` AS c50
ON
  t.user_id = c50.user_id
  AND t.param_2 = c50.param_2
  AND t.price = c50.price

  LEFT OUTER JOIN
`avito_5th.user_id_param_3_category_name_cnt` AS c51
ON
  t.user_id = c51.user_id
  AND t.param_3 = c51.param_3
  AND t.category_name = c51.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_param_3_image_top_1_cnt` AS c52
ON
  t.user_id = c52.user_id
  AND t.param_3 = c52.param_3
  AND t.image_top_1 = c52.image_top_1


  LEFT OUTER JOIN
`avito_5th.user_id_param_3_price_cnt` AS c53
ON
  t.user_id = c53.user_id
  AND t.param_3 = c53.param_3
  AND t.price = c53.price

  LEFT OUTER JOIN
`avito_5th.user_id_price_image_top_1_cnt` AS c54
ON
  t.user_id = c54.user_id
  AND t.price = c54.price
  AND t.image_top_1 = c54.image_top_1


--
  LEFT OUTER JOIN
`avito_5th.category_name_price_image_top_1_uq_minmax` AS uqmmd1
ON
  t.category_name = uqmmd1.category_name
  AND t.price = uqmmd1.price

  LEFT OUTER JOIN
`avito_5th.city_category_name_image_top_1_uq_minmax` AS uqmmd2
ON
  t.city = uqmmd2.city
  AND t.category_name = uqmmd2.category_name

  LEFT OUTER JOIN
`avito_5th.city_category_name_price_uq_minmax` AS uqmmd3
ON
  t.city = uqmmd3.city
  AND t.category_name = uqmmd3.category_name

  LEFT OUTER JOIN
`avito_5th.city_param_1_category_name_uq_minmax` AS uqmmd4
ON
  t.city = uqmmd4.city
  AND t.param_1 = uqmmd4.param_1

  LEFT OUTER JOIN
`avito_5th.city_param_1_image_top_1_uq_minmax` AS uqmmd5
ON
  t.city = uqmmd5.city
  AND t.param_1 = uqmmd5.param_1

  LEFT OUTER JOIN
`avito_5th.city_param_1_param_2_uq_minmax` AS uqmmd6
ON
  t.city = uqmmd6.city
  AND t.param_1 = uqmmd6.param_1

  LEFT OUTER JOIN
`avito_5th.city_param_1_param_3_uq_minmax` AS uqmmd7
ON
  t.city = uqmmd7.city
  AND t.param_1 = uqmmd7.param_1

  LEFT OUTER JOIN
`avito_5th.city_param_1_price_uq_minmax` AS uqmmd8
ON
  t.city = uqmmd8.city
  AND t.param_1 = uqmmd8.param_1

  LEFT OUTER JOIN
`avito_5th.city_param_2_category_name_uq_minmax` AS uqmmd9
ON
  t.city = uqmmd9.city
  AND t.param_2 = uqmmd9.param_2

  LEFT OUTER JOIN
`avito_5th.city_param_2_image_top_1_uq_minmax` AS uqmmd10
ON
  t.city = uqmmd10.city
  AND t.param_2 = uqmmd10.param_2

  LEFT OUTER JOIN
`avito_5th.city_param_2_param_3_uq_minmax` AS uqmmd11
ON
  t.city = uqmmd11.city
  AND t.param_2 = uqmmd11.param_2

  LEFT OUTER JOIN
`avito_5th.city_param_2_price_uq_minmax` AS uqmmd12
ON
  t.city = uqmmd12.city
  AND t.param_2 = uqmmd12.param_2

  LEFT OUTER JOIN
`avito_5th.city_param_3_category_name_uq_minmax` AS uqmmd13
ON
  t.city = uqmmd13.city
  AND t.param_3 = uqmmd13.param_3

  LEFT OUTER JOIN
`avito_5th.city_param_3_image_top_1_uq_minmax` AS uqmmd14
ON
  t.city = uqmmd14.city
  AND t.param_3 = uqmmd14.param_3

  LEFT OUTER JOIN
`avito_5th.city_price_image_top_1_uq_minmax` AS uqmmd15
ON
  t.city = uqmmd15.city
  AND t.price = uqmmd15.price

  LEFT OUTER JOIN
`avito_5th.param_1_category_name_image_top_1_uq_minmax` AS uqmmd16
ON
  t.param_1 = uqmmd16.param_1
  AND t.category_name = uqmmd16.category_name

  LEFT OUTER JOIN
`avito_5th.param_1_category_name_price_uq_minmax` AS uqmmd17
ON
  t.param_1 = uqmmd17.param_1
  AND t.category_name = uqmmd17.category_name

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_category_name_uq_minmax` AS uqmmd18
ON
  t.param_1 = uqmmd18.param_1
  AND t.param_2 = uqmmd18.param_2

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_image_top_1_uq_minmax` AS uqmmd19
ON
  t.param_1 = uqmmd19.param_1
  AND t.param_2 = uqmmd19.param_2

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_param_3_uq_minmax` AS uqmmd20
ON
  t.param_1 = uqmmd20.param_1
  AND t.param_2 = uqmmd20.param_2

  LEFT OUTER JOIN
`avito_5th.param_1_param_2_price_uq_minmax` AS uqmmd21
ON
  t.param_1 = uqmmd21.param_1
  AND t.param_2 = uqmmd21.param_2

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_category_name_uq_minmax` AS uqmmd22
ON
  t.param_1 = uqmmd22.param_1
  AND t.param_3 = uqmmd22.param_3

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_image_top_1_uq_minmax` AS uqmmd23
ON
  t.param_1 = uqmmd23.param_1
  AND t.param_3 = uqmmd23.param_3

  LEFT OUTER JOIN
`avito_5th.param_1_param_3_price_uq_minmax` AS uqmmd24
ON
  t.param_1 = uqmmd24.param_1
  AND t.param_3 = uqmmd24.param_3

  LEFT OUTER JOIN
`avito_5th.param_1_price_image_top_1` AS uqmmd25
ON
  t.param_1 = uqmmd25.param_1
  AND t.price = uqmmd25.price

  LEFT OUTER JOIN
`avito_5th.param_2_category_name_image_top_1_uq_minmax` AS uqmmd26
ON
  t.param_2 = uqmmd26.param_2
  AND t.category_name = uqmmd26.category_name

  LEFT OUTER JOIN
`avito_5th.param_2_category_name_price` AS uqmmd27
ON
  t.param_2 = uqmmd27.param_2
  AND t.category_name = uqmmd27.category_name

  LEFT OUTER JOIN
`avito_5th.param_2_param_3_image_top_1_uq_minmax` AS uqmmd28
ON
  t.param_2 = uqmmd28.param_2
  AND t.param_3 = uqmmd28.param_3

  LEFT OUTER JOIN
`avito_5th.param_2_param_3_price_uq_minmax` AS uqmmd29
ON
  t.param_2 = uqmmd29.param_2
  AND t.param_3 = uqmmd29.param_3

  LEFT OUTER JOIN
`avito_5th.param_2_price_image_top_1_uq_minmax` AS uqmmd30
ON
  t.param_2 = uqmmd30.param_2
  AND t.price = uqmmd30.price

  LEFT OUTER JOIN
`avito_5th.param_3_category_name_image_top_1_uq_minmax` AS uqmmd31
ON
  t.param_3 = uqmmd31.param_3
  AND t.category_name = uqmmd31.category_name

  LEFT OUTER JOIN
`avito_5th.param_3_category_name_price_uq_minmax` AS uqmmd32
ON
  t.param_3 = uqmmd32.param_3
  AND t.category_name = uqmmd32.category_name

  LEFT OUTER JOIN
`avito_5th.param_3_price_image_top_1_uq_minmax` AS uqmmd33
ON
  t.param_3 = uqmmd33.param_3
  AND t.price = uqmmd33.price

  LEFT OUTER JOIN
`avito_5th.user_id_category_name_image_top_1_uq_minmax` AS uqmmd34
ON
  t.user_id = uqmmd34.user_id
  AND t.category_name = uqmmd34.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_category_name_price_uq_minmax` AS uqmmd35
ON
  t.user_id = uqmmd35.user_id
  AND t.category_name = uqmmd35.category_name

  LEFT OUTER JOIN
`avito_5th.user_id_city_category_name_uq_minmax` AS uqmmd36
ON
  t.user_id = uqmmd36.user_id
  AND t.city = uqmmd36.city

  LEFT OUTER JOIN
`avito_5th.user_id_city_image_top_1_uq_minmax` AS uqmmd37
ON
  t.user_id = uqmmd37.user_id
  AND t.city = uqmmd37.city

  LEFT OUTER JOIN
`avito_5th.user_id_city_param_1_uq_minmax` AS uqmmd38
ON
  t.user_id = uqmmd38.user_id
  AND t.city = uqmmd38.city

  LEFT OUTER JOIN
`avito_5th.user_id_city_param_2_uq_minmax` AS uqmmd39
ON
  t.user_id = uqmmd39.user_id
  AND t.city = uqmmd39.city

  LEFT OUTER JOIN
`avito_5th.user_id_city_param_3_uq_minmax` AS uqmmd40
ON
  t.user_id = uqmmd40.user_id
  AND t.city = uqmmd40.city

  LEFT OUTER JOIN
`avito_5th.user_id_city_price_uq_minmax` AS uqmmd41
ON
  t.user_id = uqmmd41.user_id
  AND t.city = uqmmd41.city

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_category_name_uq_minmax` AS uqmmd42
ON
  t.user_id = uqmmd42.user_id
  AND t.param_1 = uqmmd42.param_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_image_top_1_uq_minmax` AS uqmmd43
ON
  t.user_id = uqmmd43.user_id
  AND t.param_1 = uqmmd43.param_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_param_2_uq_minmax` AS uqmmd44
ON
  t.user_id = uqmmd44.user_id
  AND t.param_1 = uqmmd44.param_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_param_3_uq_minmax` AS uqmmd45
ON
  t.user_id = uqmmd45.user_id
  AND t.param_1 = uqmmd45.param_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_1_price_uq_minmax` AS uqmmd46
ON
  t.user_id = uqmmd46.user_id
  AND t.param_1 = uqmmd46.param_1

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_category_name_uq_minmax` AS uqmmd47
ON
  t.user_id = uqmmd47.user_id
  AND t.param_2 = uqmmd47.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_image_top_1_uq_minmax` AS uqmmd48
ON
  t.user_id = uqmmd48.user_id
  AND t.param_2 = uqmmd48.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_param_3_uq_minmax` AS uqmmd49
ON
  t.user_id = uqmmd49.user_id
  AND t.param_2 = uqmmd49.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_param_2_price_uq_minmax` AS uqmmd50
ON
  t.user_id = uqmmd50.user_id
  AND t.param_2 = uqmmd50.param_2

  LEFT OUTER JOIN
`avito_5th.user_id_param_3_category_name_uq_minmax` AS uqmmd51
ON
  t.user_id = uqmmd51.user_id
  AND t.param_3 = uqmmd51.param_3

  LEFT OUTER JOIN
`avito_5th.user_id_param_3_image_top_1_uq_minmax` AS uqmmd52
ON
  t.user_id = uqmmd52.user_id
  AND t.param_3 = uqmmd52.param_3

  LEFT OUTER JOIN
`avito_5th.user_id_param_3_price_uq_minmax` AS uqmmd53
ON
  t.user_id = uqmmd53.user_id
  AND t.param_3 = uqmmd53.param_3

  LEFT OUTER JOIN
`avito_5th.user_id_price_image_top_1_uq_minmax` AS uqmmd54
ON
  t.user_id = uqmmd54.user_id
  AND t.price = uqmmd54.price


----------
-- NNモデルの前処理で使用したuq_rateをテキストデータに紐づけるクエリ
-- 1. item_id, uq_rateのカラムで構成したcsvをBigQueryにUPする．
-- 2. 以下のクエリを実行する
-- →　これで，新出語との対応を簡単にみることができるようになった．直接ユニーク語をとってきて比較してもよい
SELECT
  t.*,
  CONCAT(tt.title, " ", tt.description) AS title_desc
FROM
  `bqtest-114514.avito_other_features.train_test_text_uq_rate` AS t
LEFT OUTER JOIN
  `avito.train_test` AS tt
ON
  t.item_id = tt.item_id



----
-- _avito_6th

SELECT
  item_id,
  EXTRACT(MONTH FROM TIMESTAMP(activation_date)) AS month,
  EXTRACT(WEEK FROM TIMESTAMP(activation_date)) AS week,
  EXTRACT(DAYOFWEEK FROM TIMESTAMP(activation_date)) AS dayofweek,
  EXTRACT(DAY FROM TIMESTAMP(activation_date)) AS day
FROM
  `bqtest-114514.avito.train_test`


--
SELECT
  _5.*,
  t.week,
  t.dayofweek,
  t.day
FROM
  `bqtest-114514.avito_6th._month_week_dayofweek` as t
LEFT OUTER JOIN
`avito_5th._5th_feature` as _5
ON t.item_id = _5.item_id


---
-- avito_7th
--- 標準偏差の計算
----- 1st step
SELECT
  t.item_id,
  STDDEV(t.price) OVER(PARTITION BY t.city) AS std_price_by_city,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.city) AS std_image_top_1_by_city,
  STDDEV(t.price) OVER(PARTITION BY t.user_id) AS std_price_by_user_id,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.user_id) AS std_image_top_1_by_user_id,
  STDDEV(t.price) OVER(PARTITION BY t.region) AS std_price_by_region,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.region) AS std_image_top_1_by_region,
  STDDEV(t.price) OVER(PARTITION BY t.parent_category_name) AS std_price_by_parent_category_name,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.parent_category_name) AS std_image_top_1_by_parent_category_name,
  STDDEV(t.price) OVER(PARTITION BY t.category_name) AS std_price_by_category_name,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.category_name) AS std_image_top_1_by_category_name,
  STDDEV(t.price) OVER(PARTITION BY t.param_1) AS std_price_by_param_1,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.param_1) AS std_image_top_1_by_param_1,
  STDDEV(t.price) OVER(PARTITION BY t.param_2) AS std_price_by_param_2,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.param_2) AS std_image_top_1_by_param_2,
  STDDEV(t.price) OVER(PARTITION BY t.param_3) AS std_price_by_param_3,
  STDDEV(t.image_top_1) OVER(PARTITION BY t.param_3) AS std_image_top_1_by_param_3,
  STDDEV(t.image_top_1) OVER(PARTITION BY CAST(t.price AS INT64)) AS std_image_top_1_by_price,
  STDDEV(t.price) OVER(PARTITION BY CAST(t.image_top_1 AS INT64)) AS std_image_top_1_by_image_top_1, # price_by_image_top_1の間違え
  STDDEV(t.price) OVER(PARTITION BY CAST(t.week AS INT64)) AS std_price_by_week,
  STDDEV(t.image_top_1) OVER(PARTITION BY CAST(t.week AS INT64)) AS std_image_top_1_by_week,
  STDDEV(t.price) OVER(PARTITION BY CAST(t.dayofweek AS INT64)) AS std_price_by_dayofweek,
  STDDEV(t.image_top_1) OVER(PARTITION BY CAST(t.dayofweek AS INT64)) AS std_image_top_1_by_dayofweek,
  STDDEV(t.price) OVER(PARTITION BY CAST(t.day AS INT64)) AS std_price_by_day,
  STDDEV(t.image_top_1) OVER(PARTITION BY CAST(t.day AS INT64)) AS std_image_top_1_by_day
FROM
  `bqtest-114514.avito_6th._6th_feature` AS t

----- 2nd 
SELECT
  t.item_id,
  IFNULL(STDDEV(t.week) OVER(PARTITION BY t.user_id), -1) AS std_week_by_user_id,
  IFNULL(STDDEV(t.dayofweek) OVER(PARTITION BY t.user_id), -1) AS std_dayofweek_by_user_id,
  IFNULL(STDDEV(t.day) OVER(PARTITION BY t.user_id), -1) AS std_day_by_user_id
FROM
  `bqtest-114514.avito_6th._6th_feature` AS t


---8th
-- 外部人口データをJoin　（最初のクエリはNullを含んでしまうので，各自調べて次のクエリでNullを穴埋めして，UnionAll）
SELECT
  t.item_id,
  t.region,
  t.city,
  rcp.population
FROM
  `bqtest-114514.avito.train_test` AS t
INNER JOIN
  `avito_external.region_city_population` AS rcp
ON
  t.city = rcp.city
  AND t.region = rcp.region
UNION ALL
SELECT
  t.item_id,
  t.region,
  t.city,
  cp.population
FROM
  `bqtest-114514.avito.train_test` AS t
INNER JOIN
  `avito_external.city_population` AS cp
ON
  t.city = cp.city

-- item_idで6th_featureとLeft outer join -> _8th_feature
SELECT
  t.*,
  tip.population
FROM
  `bqtest-114514.avito_6th._6th_feature` AS t
LEFT OUTER JOIN
  `bqtest-114514.avito_8th.__tmp_item_id_population` AS tip
ON
  t.item_id = tip.item_id


--- region_macros（外部データ）と8th_featureのleft outer join
SELECT
  t.*,
  rm.unemployment_rate,
  rm.GDP_PC_PPP,
  rm.HDI
FROM
  `bqtest-114514.avito_8th._8th_feature` AS t
LEFT OUTER JOIN
  `bqtest-114514.avito_external.region_macro` AS rm
ON
  t.region = rm.region