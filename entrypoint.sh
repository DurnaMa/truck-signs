#!/usr/bin/env bash
set -e

cd /app/src 

echo "Waiting for postgres to connect ..."

# Wait for the database to be up and ready, if not ready, then sleep for 5 seconds
while ! nc -z "${DB_HOST}" "${DB_PORT}"; do
  echo "Waiting for database connection..."
  sleep 5
done

echo "PostgreSQL is active"

python manage.py collectstatic --noinput

python manage.py migrate --noinput

if python manage.py shell -c \
    "from django.contrib.auth.models import User; \
    import os; \
    import sys; \
    gibt_es = User.objects.filter(username=os.getenv('SUPER_USER_NAME')).exists(); \
    code    = 0 if gibt_es else 1; \
    sys.exit(code)"; then
    echo "Superuser already exists"
else
    echo "Creating superuser"
    DJANGO_SUPERUSER_PASSWORD="${SUPER_USER_PASSWORD}" python manage.py createsuperuser \
      --username "${SUPER_USER_NAME}" --email "${SUPER_USER_EMAIL}" --noinput
fi

echo "Postgresql migrations finished"

exec gunicorn tsa_app.wsgi:application --bind 0.0.0.0:8000 --workers 4
