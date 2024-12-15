# Nginx con vigilancia de carpetas

Esta imagen de Docker es una mejora del la imagen oficial de nginx para que haga la vigilancia de directorios.

Se ha añadido la opción de que vigile los cambios en los directorios definidos en la variable de entorno `$DIRECTORIOS` mediante `inofitywait`. Si ocurre algún cambio, se espera 10 minutos antes de recargar la configuración de nginx mediante `kill -HUP ${NGINX_PID}`.

También se puede cambiar con que `UID` (id de usuario) y `GID`(id de grupo) trabaja Nginx mediante variables de entorno. Si no se definen, trabaja como en la imagen oficial. 

## Como usar

### A través de Docker Compose

```yml
version: "3"

services :
  nginx:
    image: pepramon/nginx
    volumes:
      # Configuración típica de Nginx
      - ./conf.d:/etc/nginx/conf.d
    environment:
      # Ejemplo de vigilancia de 2 directorios
      - DIRECTORIOS="/etc/example /var/www"
      # Hacer que corra con UID 1000, GID 1000
      - UID=1000
      - GID=1000
```

### Mediante Docker run

Igual que en Docker Compose pero con un comando

```bash
docker run -d -v ./conf.d:/etc/nginx/conf.d -e DIRECTORIOS="/etc/example /var/www"  -e UID=1000 -e GID=1000 pepramon/nginx
```

## Soporte y colaboración

Aunque el punto de desarrollo de este proyecto está en un servidor de Gitea propio, se actualiza automáticamente el servidor de Github, y por tanto, cualquier comentario será bienvenido.

[https://github.com/pepramon/nginx](https://github.com/pepramon/nginx).

## Actualización de la imagen en DockerHub

Como se ha comentado anteriormente, el proyecto está alojado en un servidor de Gitea propio, una de las razones para ello es poder mantener actualiza la imagen de DockerHub de manera automática.

La imagen [https://hub.docker.com/r/pepramon/nginx](https://hub.docker.com/r/pepramon/nginx) se actualiza automáticamente en los siguiente supuestos:

* La imagen base de Nginx ha cambiado
* Se ha modificado el Dockerfile o el script `script_inicio.sh` de la raíz del repositorio

Para saber si la imagen base de CertBoot ha cambiado respecto a la construida, se almacena una etiqueta en el interior de la imagen generada que tiene el SHA de la imagen base (revisar `.gitea/workflows/` para ver como se hace).

La construcción se hace mediante Podman con el contenedor personalizado alojado en [https://github.com/pepramon/gitea-runner](https://github.com/pepramon/gitea-runner)