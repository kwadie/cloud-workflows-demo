CREATE OR REPLACE PROCEDURE `${project}.${dataset}.${sproc_name}`()
BEGIN
  TRUNCATE TABLE `${project}.${dataset}.word_count_aggregate`;

  INSERT INTO  `${project}.${dataset}.word_count_aggregate`
  SELECT word, SUM(word_count) AS word_count FROM  `${project}.${dataset}.word_count_output` GROUP BY 1;
END