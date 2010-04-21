#!/bin/sh

(
  echo use sandbox;
  echo db.colors.drop;
  echo db.colors.insert\({ \"name\" : \"blue\" }\);
  echo db.colors.insert\({ \"name\" : \"red\" }\);
  sleep 1
) | mongo
