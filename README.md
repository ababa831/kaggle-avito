# kaggle-avito

[Avito](https://www.kaggle.com/c/avito-demand-prediction)で使用したコードを整理して，Upしていく予定．


**注意**<br>
このコンペは，プライベートの時間の制約上，画像データまで手がつけられず特徴量の選定もあまり丁寧に行っていないため，あまり参考にならない．（そもそも上位入賞していない．）

## 各種ファイルの説明
- bi_lstm_gru.ipynb

テキストデータをembeddingして，RNN（LSTM＋GRU）で学習したもの．重みづけには，学習済みのfastTextが用いられている．[Avitoの外部データスレッド](https://www.kaggle.com/c/avito-demand-prediction/discussion/55897)を参照．
<br>
- avito_lgbm_w_bi_lstm_gru_to_github.ipynb

テキストデータをRNN（LSTM＋GRU）する弱学習器とカテゴリカル変数，量的変数から作成した特徴量を組み合わせ，アンサンブル学習(stacking)したもの．
<br>
- feature_engineering.sql

特徴エンジニアリングの大部分は，BigQueryで行った．このファイルは，特徴量作成用のコードをメモ書きしたもの．