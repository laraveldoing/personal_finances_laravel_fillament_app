# Project Title

## Overview

Brief description of the personal finances Laravel Fillament app.

## Installation

```bash
composer install
php artisan migrate
```

## Usage

```bash
php artisan serve
```

## Commands

- `php artisan migrate` – run migrations.
- `php artisan db:seed` – seed database.

## Configuration

### Supabase Connection

The application uses a PostgreSQL database hosted on Supabase. Configure the connection via the `.env` file:

```dotenv
DATABASE_URL=postgresql://postgres:<URL-ENCODED-PASSWORD>@db.evqczgfbbghahsmqqmqg.supabase.co:5432/postgres
DB_HOST=db.evqczgfbbghahsmqqmqg.supabase.co
DB_PORT=5432
DB_DATABASE=postgres
DB_USERNAME=postgres
DB_PASSWORD=<YOUR-PASSWORD>
```

* The password must be URL‑encoded (e.g., `+` → `%2B`, `*` → `%2A`).
* Install the PHP `pdo_pgsql` extension (or enable it in `php.ini`).
* After installing dependencies (`composer install`) and setting the `.env` values, test the connection:

```bash
php ./artisan   # should output "Connected successfully"
```

If you encounter `could not find driver`, ensure `pdo_pgsql` is installed and enabled.

