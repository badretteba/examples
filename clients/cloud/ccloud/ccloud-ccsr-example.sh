#!/bin/bash

source ../../../utils/helper.sh
source ../../../utils/ccloud_library.sh 

ccloud::validate_expect_installed \
  && print_pass "expect installed" \
  || exit 1
check_timeout \
  && print_pass "timeout installed" \
  || exit 1
ccloud::validate_version_ccloud_cli 1.13.0 \
  && print_pass "ccloud version ok" \
  || exit 1
ccloud::validate_logged_in_ccloud_cli \
  && print_pass "logged into ccloud CLI" \
  || exit 1

if [[ -z "$SR_API_KEY" ]] || [[ -z "$SR_API_SECRET" ]] ; then
  echo "ERROR: You must export SR_API_KEY and SR_API_SECRET before running this script"
  exit 1
fi

# Set topic name
topic_name=test2

# Create topic in Confluent Cloud
echo -e "\n# Create topic $topic_name"
ccloud kafka topic create $topic_name || true

# Run producer to set credentials to Confluent Cloud Schema Registry (bit of a hack)
echo -e "\n# Set credentials to Confluent Cloud Schema Registry"
OUTPUT=$(
expect <<END
  log_user 1
  spawn ccloud kafka topic produce $topic_name --value-format avro --schema schema.json
  expect "Enter your Schema Registry API key: " {
    send "$SR_API_KEY\r";
    expect "Enter your Schema Registry API secret: "
    send "$SR_API_SECRET\r";
  }
  expect "Successfully registered schema with ID "
  set result $expect_out(buffer)
END
)
echo "$OUTPUT"

# Produce messages
echo -e "\n# Produce messages to $topic_name"
num_messages=10
(for i in `seq 1 $num_messages`; do echo "{\"count\":${i}}" ; done) | \
   ccloud kafka topic produce $topic_name \
            --value-format avro \
            --schema schema.json

# Consume messages
echo -e "\n# Consume messages from $topic_name"
timeout 10 ccloud kafka topic consume $topic_name -b --value-format avro
