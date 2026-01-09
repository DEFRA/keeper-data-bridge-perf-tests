#!/bin/sh
set -x

echo "run_id: $RUN_ID in $ENVIRONMENT"

NOW=$(date +"%Y%m%d-%H%M%S")

if [ -z "${JM_HOME}" ]; then
  JM_HOME=/opt/perftest
fi

JM_SCENARIOS=${JM_HOME}/scenarios
JM_REPORTS=${JM_HOME}/reports
JM_LOGS=${JM_HOME}/logs

mkdir -p ${JM_REPORTS} ${JM_LOGS}

TEST_SCENARIO=${TEST_SCENARIO:-test}
SCENARIOFILE=${JM_SCENARIOS}/${TEST_SCENARIO}.jmx
REPORTFILE=${NOW}-perftest-${TEST_SCENARIO}-report.csv
LOGFILE=${JM_LOGS}/perftest-${TEST_SCENARIO}.log

# Before running the suite, configure these environment variables:
# ENVIRONMENT is set to the name of the environment the test is running in.
SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-service-name.${ENVIRONMENT}.cdp-int.defra.cloud}
SERVICE_PORT=${SERVICE_PORT:-443}
SERVICE_URL_SCHEME=${SERVICE_URL_SCHEME:-https}
# Path prefix: set to service name for ephemeral-protected gateway, empty for direct access
SERVICE_PATH_PREFIX=${SERVICE_PATH_PREFIX:-}
# API authentication keys
API_KEY=${API_KEY:-}
GATEWAY_API_KEY=${GATEWAY_API_KEY:-}

# Run the test suite
jmeter -n -t ${SCENARIOFILE} -e -l "${REPORTFILE}" -o ${JM_REPORTS} -j ${LOGFILE} -f \
-Jenv="${ENVIRONMENT}" \
-Jdomain="${SERVICE_ENDPOINT}" \
-Jport="${SERVICE_PORT}" \
-Jprotocol="${SERVICE_URL_SCHEME}" \
-Jpathprefix="${SERVICE_PATH_PREFIX}" \
-Japikey="${API_KEY}" \
-Jgatewayapikey="${GATEWAY_API_KEY}"

# Publish the results into S3 so they can be displayed in the CDP Portal
if [ -n "$RESULTS_OUTPUT_S3_PATH" ]; then
  # Copy the CSV report file and the generated report files to the S3 bucket
   if [ -f "$JM_REPORTS/index.html" ]; then
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$REPORTFILE" "$RESULTS_OUTPUT_S3_PATH/$REPORTFILE"
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$JM_REPORTS" "$RESULTS_OUTPUT_S3_PATH" --recursive
      if [ $? -eq 0 ]; then
        echo "CSV report file and test results published to $RESULTS_OUTPUT_S3_PATH"
      fi
   else
      echo "$JM_REPORTS/index.html is not found"
      exit 1
   fi
else
   echo "RESULTS_OUTPUT_S3_PATH is not set"
   exit 1
fi

exit $test_exit_code
