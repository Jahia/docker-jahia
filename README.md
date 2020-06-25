# Jahia Enterprise Docker image

## Build image
| build arg      | default                                                                                                       | comment                                                                   |
|----------------|---------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `BASE_URL`     | `https://downloads.jahia.com/downloads/jahia/jahia7.3.4/Jahia-EnterpriseDistribution-7.3.4.1-r60321.4663.jar` |                                                                           |
| `DBMS_TYPE`    | `mariadb`                                                                                                     | can be `mariadb` or `postgresql`                                          |
| `DEBUG_TOOLS`  | `false`                                                                                                       | set to `true` in order to install `vim` and `binutils`                    |
| `FFMPEG`       | `false`                                                                                                       | set to `true` in order to install `ffmpeg` and enable it for Jahia        |
| `LIBREOFFICE`  | `false`                                                                                                       | set to `true` in order to install `libreoffice` and enable it for Jahia   |
| `DS_IN_DB`     | `true`                                                                                                        | `true` for store files in database, `false` for store files in filesystem |
| `DS_PATH`      | `/datastore/jahia`                                                                                            | datastore path if `DS_IN_DB` is set to `false`                            |
| `LOG_MAX_DAYS` | `5`                                                                                                           | Set the default image logs retention rule                                 |


## Use image
### Requirements
You must have a `mariadb` or `postgresql` DBMS with a Jahia's schema import in a database.
You can find the create scripts in the image here: `/data/digital-factory-data/db/sql/schema/{mysql,postgresql}`

### Instanciate
| env var                 | default                      | comment                                                                                               |
|-------------------------|------------------------------|-------------------------------------------------------------------------------------------------------|
| `DB_HOST`               | `mariadb`                    |                                                                                                       |
| `DB_NAME`               | `jahia`                      |                                                                                                       |
| `DB_USER`               | `jahia`                      |                                                                                                       |
| `DB_PASS`               | `fakepassword`               |                                                                                                       |
| `SUPER_USER_PASSWORD`   | `fakepassword`               | Jahia's _root_ password                                                                               |
| `JMANAGER_USER`         | `jahia`                      | Jahia's _/tools_ user                                                                                 |
| `JMANAGER_PASS`         | `fakepassword`               | Jahia's _/tools_ password                                                                             |
| `MAX_UPLOAD`            | `268435456`                  | max file size upload to Jahia                                                                         |
| `OPERATING_MODE`        | `development`                | can be `development` or `production`                                                                  |
| `PROCESSING_SERVER`     | `false`                      | `false` for _browsing_ container, `true` for _processing_ one                                         |
| `MAVEN_XMX`             | `256m`                       | set a maximum heap for maven                                                                          |
| `MAX_RAM_PERCENTAGE`    | `25`                         | percentage of the container limit to use forjahia memory heap (be aware that Jahia need at least 2GB) |
| `RESTORE_MODULE_STATES` | `true`                       | restore modules and their states from database (forced to `false` when database is empty)             |
| `LOG_MAX_DAYS`          | `5` (can be change at build) | Set container's logs retention rule                                                                   |


## Image build

### Bypass the installer.jar download and provide your own
In case a file installer.jar is present in the same folder as the dockerfile during the build, this installer is used instead of the one referenced in the Dockerfile

### Specifics for Jahia <8
It is necessary to add the parameter `--build-arg INSTALL_FILE_SUFFIX=""` to the build command

## Instanciate
### Using license file
In order to use your license file, use _volume_, eg:
```bash
docker run [some docker options here] \
    -e PROCESSING_SERVER="true" \
    -v /your/path/to/a/license.xml:/usr/local/tomcat/conf/digital-factory-config/jahia/license.xml:ro \
    [some other envs here] \
    jahia/docker-enterprise:7.3.4.1

```
### Be aware of MAX_RAM_PERCENTAGE
OpenJDK 11 default in a container context is tu use 25% of the container's memory limit.
Please set this variable to always have at least 2GB for Jahia's heap.
