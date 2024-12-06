#!/bin/bash

while ! kubectl kustomize example | kubectl apply --server-side --force-conflicts -f -; do echo "Retrying to apply resources"; sleep 20; done