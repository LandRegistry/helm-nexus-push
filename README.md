<!--

 Copyright 2018-present Sonatype, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

-->
# Helm Nexus Repository Push

A Helm plugin that pushes a chart directory or packaged chart tgz to a specified
Nexus Helm repo.

## Prerequisites

* Helm 4
* Bash
* `curl`

## Installation

Clone the updated plugin checkout and install it with Helm:

```sh
git clone https://github.com/LandRegistry/helm-nexus-push.git
cd helm-nexus-push
helm plugin install .
helm nexus-push --help
```

Helm 4 verifies signatures when installing plugin archives by default. This
project does not publish signed plugin archives; installing a local checkout as
shown above is treated as local development and does not require a signature.
Review the source before installing or bypassing signature verification.

## Updates

For plugins installed from a source Helm can update, run:

```sh
helm plugin update nexus-push
```

## Usage

First register the Nexus Helm repository by name:

```sh
helm repo add myrepo https://nexus.example.com/repository/helm-hosted
```

Push either a chart directory (packaged by Helm) or an existing chart archive:

```sh
helm nexus-push myrepo ./mychart
helm nexus-push myrepo ./mychart-0.0.1.tgz
```

Additional help available `helm nexus-push --help`

## Authentication

Pass `-u`/`--username` and `-p`/`--password` to provide credentials for a
push or login. Explicit values take precedence over cached credentials; any
missing values are taken from the cache and then prompted for interactively.
`helm nexus-push <repo> login` saves credentials, and
`helm nexus-push <repo> logout` removes them. Credentials are stored in
`auth.<repo>` under Helm's configuration directory with owner-only permissions.
If a required credential is missing and input is unavailable, the command fails.

## Getting help

This is an unsupported fork of the original archived repository.
