#!/usr/bin/python

#!/bin/bash

#
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from pyspark.sql import SparkSession
from pyspark.sql.functions import lit
import argparse

spark = SparkSession \
    .builder \
    .appName('spark-bigquery-demo') \
    .getOrCreate()

parser = argparse.ArgumentParser()
parser.add_argument("--input_expression", help="GCS input path to read from. gs://bucket/path or gs://bucket/file ")
parser.add_argument("--output_table", help="Bigquery table to write word count results. Format project:dataset.table")
parser.add_argument("--temp_bucket", help="GCS path to store temp files. Format bucket/path/ without gs://")
args = parser.parse_args()

# Use the Cloud Storage bucket for temporary BigQuery export data used
# by the connector in case of writeMethod=indirect
spark.conf.set('temporaryGcsBucket', args.temp_bucket)

sc = spark.sparkContext
lines = sc.textFile(args.input_expression)
words = lines.flatMap(lambda line: line.split())
word_count = words\
    .map(lambda word: (word, 1))\
    .reduceByKey(lambda count1, count2: count1 + count2)

output_columns = ["word", "word_count"]
word_count_df = word_count.toDF(output_columns)

# add the file path as a literal column
word_count_df = word_count_df.withColumn("input_file", lit(args.input_expression))

word_count_df.show()
word_count_df.printSchema()

# # Saving the data to BigQuery
# # FIXME: writeMethod=direct uses Storage WriteAPI but it fails due to schema mismatch between dataframe and table which doesn't seem true
# # https://github.com/GoogleCloudDataproc/spark-bigquery-connector#writing-data-to-bigquery
word_count_df.write.format('bigquery') \
    .option("table", args.output_table) \
    .option("writeMethod", "indirect") \
    .option("createDisposition", "CREATE_IF_NEEDED") \
    .mode("append") \
    .save()
