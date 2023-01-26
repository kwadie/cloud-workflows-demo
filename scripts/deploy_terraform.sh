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

# exit script when errors occur
#set -e

# set the working dir as the scripts directory
cd "$(dirname "$0")"

cd ../terraform

echo "impersonate_service_account will be ${TF_SA}@${PROJECT_ID}.iam.gserviceaccount.com at storage bucket ${BUCKET}"

terraform init \
    -backend-config="bucket=${BUCKET}" \
    -backend-config="prefix=terraform-state" \
    -backend-config="impersonate_service_account=${TF_SA}@${PROJECT_ID}.iam.gserviceaccount.com"


terraform apply -var-file="${VARS}" -auto-approve