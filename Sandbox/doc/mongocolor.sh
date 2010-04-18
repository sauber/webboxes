#!/bin/sh

(
  echo use sandbox;
  echo db.sandbox.colors.drop;
  echo db.sandbox.colors.insert\({ \"name\" : \"blue\" }\);
  echo db.sandbox.colors.insert\({ \"name\" : \"red\" }\);
  sleep 1
) | mongo
