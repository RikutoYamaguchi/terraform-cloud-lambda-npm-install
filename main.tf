provider "aws" {
  region  = "ap-northeast-1"
  version = "~> 3.6"
}

terraform {
  required_version = "0.13.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_iam_policy_document" "lambda_assume_role_document" {
  statement {
    effect = "Allow"

    principals {
      identifiers = [
        "lambda.amazonaws.com"
      ]
      type = "Service"
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

locals {
  lambda_root = "./lambda"

  sample_function_source = "${local.lambda_root}/sample_function"
  sample_function_output = "${local.lambda_root}/sample_function.zip"

  sample_layers_source       = "${local.lambda_root}/layers"
  sample_layers_package_json = "${local.sample_layers_source}/nodejs/package.json"
  sample_layers_build_shell  = "${local.sample_layers_source}/nodejs/build.sh"
}

resource "null_resource" "sample_layer_source_build" {
  triggers = {
    layer_build = filebase64sha256(local.sample_layers_source)
  }
  provisioner "local-exec" {
    working_dir = local.lambda_root
    command     = <<EOF
      mkdir ./node_install && \
      cd ./node_install && \
      curl https://nodejs.org/dist/v12.19.0/node-v12.19.0-linux-x64.tar.gz | tar xz --strip-components=1 && \
      export PATH="$PWD/bin:$PATH" && \
      cd ../ && \
      chmod +x ${local.sample_layers_build_shell} && \
      ${local.sample_layers_build_shell}
    EOF
  }
}

data "archive_file" "appsync_resolver_nodejs_layer" {
  type        = "zip"
  source_dir  = local.sample_layers_source
  output_path = "${local.lambda_root}/layers-${filebase64sha256(local.sample_layers_package_json)}.zip"
  depends_on  = [null_resource.sample_layer_source_build]
}

resource "aws_lambda_layer_version" "sample_nodejs_layer" {
  filename            = data.archive_file.appsync_resolver_nodejs_layer.output_base64sha256
  layer_name          = "sample_nodejs_layer"
  compatible_runtimes = ["nodejs12.x"]
}

resource "aws_iam_role" "lambda" {
  name               = "sample-lambda-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_document.json
}

resource "aws_iam_role_policy_attachment" "aws_lambda_basic_execution_role" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_sample_function" {
  type        = "zip"
  source_dir  = local.sample_function_source
  output_path = local.sample_function_output
}

resource "aws_lambda_function" "sample_function" {
  filename         = data.archive_file.lambda_sample_function.output_path
  source_code_hash = data.archive_file.lambda_sample_function.output_base64sha256
  function_name    = "sample_function"
  handler          = "index.handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs12.x"
  publish          = true
  memory_size      = 128
  timeout          = 3
}
