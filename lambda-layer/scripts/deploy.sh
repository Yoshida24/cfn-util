#!/usr/bin/env bash

# exit on error
set -e

# load .env
set -a
source .env
set +a

STACK_NAME=${STACK_NAME}
TEMP_LAMBDA_LAYER_BUCKET=${STACK_NAME}-temp-bucket
TEMP_LAMBDA_LAYER_KEY=layer.zip

# Lambda Layer依存性の解決:一時的にディレクトリを作成 -> pip install -> 一時S3に依存性をアップロードする
echo "Install lambda dependencies..."

mkdir -p ./tmp_deploy/python
pip install -r requirements.txt -t ./tmp_deploy/python
zip -r9 ./tmp_deploy/layer.zip ./tmp_deploy/python

aws s3 mb s3://${TEMP_LAMBDA_LAYER_BUCKET}
aws s3 cp ./tmp_deploy/layer.zip s3://${TEMP_LAMBDA_LAYER_BUCKET}/${TEMP_LAMBDA_LAYER_KEY}

# Lambda Layerを作成する
aws cloudformation deploy \
  --template cloudformation/lambda_layer.yaml \
  --stack-name ${STACK_NAME} \
  --parameter-overrides \
    LambdaLayerS3Bucket=${TEMP_LAMBDA_LAYER_BUCKET} \
    LambdaLayerKey=${TEMP_LAMBDA_LAYER_KEY} \
    LayerName=${LAYER_NAME} \
    Description=${LAYER_DESCRIPTION} \
  --capabilities CAPABILITY_NAMED_IAM

# クリーンアップ:Lambda Layerを作成し終えたのでローカルの依存性とS3 Bucketを削除する
rm -r ./tmp_deploy
aws s3 rb s3://${TEMP_LAMBDA_LAYER_BUCKET} --force
