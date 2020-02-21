# Jahia Enterprise Docker image

## Build image
| build arg     | default                                                                                                       | comment                                                                 |
|---------------|---------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| `BASE_URL`    | `https://downloads.jahia.com/downloads/jahia/jahia7.3.4/Jahia-EnterpriseDistribution-7.3.4.1-r60321.4663.jar` |                                                                         |
| `DBMS_TYPE`   | `mariadb`                                                                                                     | can be `mariadb` or `postgresql`                                        |
| `DEBUG_TOOLS` | `false`                                                                                                       | set to `true` in order to install `vim` and `binutils`                  |
| `FFMPEG`      | `false`                                                                                                       | set to `true` in order to install `ffmpeg` and enable it for Jahia      |
| `LIBREOFFICE` | `false`                                                                                                       | set to `true` in order to install `libreoffice` and enable it for Jahia |

## Use image
### Requirements
You must have a `mariadb` or `postgresql` DBMS with a Jahia's schema import in a database.
You can find the create scripts in the image here: `/data/digital-factory-data/db/sql/schema/{mysql,postgresql}`

### Instanciate
| env var               | default        | comment                                                       |
|-----------------------|----------------|---------------------------------------------------------------|
| `DBMS_TYPE`           | `mariadb`      | can be `mariadb` or `postgresql`                              |
| `DB_HOST`             | `mariadb`      |                                                               |
| `DB_NAME`             | `jahia`        |                                                               |
| `DB_USER`             | `jahia`        |                                                               |
| `DB_PASS`             | `fakepassword` |                                                               |
| `SUPER_USER_PASSWORD` | `fakepassword` | Jahia's _root_ password                                       |
| `JMANAGER_USER`       | `jahia`        | Jahia's _/tools_ user                                         |
| `JMANAGER_PASS`       | `fakepassword` | Jahia's _/tools_ password                                     |
| `MAX_UPLOAD`          | `268435456`    | max file size upload to Jahia                                 |
| `OPERATING_MODE`      | `development`  | can be `development` or `production`                          |
| `PROCESSING_SERVER`   | `false`        | `false` for _browsing_ container, `true` for _processing_ one |
| `XMX`                 | `2048M`        |                                                               |

In order to use your license file, use _volume_, eg:
```bash
docker run [some docker options here] \
    -e PROCESSING_SERVER="true" \
    -v /your/path/to/a/license.xml:/usr/local/tomcat/conf/digital-factory-config/jahia/license.xml:ro \
    [some other envs here] \
    jahia/docker-enterprise:7.3.4.1

```
