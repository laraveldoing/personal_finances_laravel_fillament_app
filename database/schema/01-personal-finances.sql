-- Esquema de dominio de la aplicación de finanzas personales.
--
-- Origen: script entregado por la persona responsable del proyecto (2026-09-22). Se aplicó tal cual
-- sobre la base de datos `personal_finances` del contenedor MySQL definido en `docker-compose.yml`
-- (el nombre aparece en singular en las dos líneas comentadas de abajo: no se descomentan, la base
-- ya existe con el nombre en plural).
--
-- Cambio de semántica (2026-09-23, decisión D19 en `/plans/schema-import-and-filament.md`): las
-- reglas `ON DELETE` de tres claves foráneas dejaron de ser `CASCADE` para proteger el historial
-- financiero — `fk_transactions_account` → `RESTRICT`, `fk_transactions_category` → `SET NULL`
-- (por eso `transactions.category_id` es NULL) y `fk_budgets_category` → `RESTRICT`. Los cascades
-- sobre `users` (`fk_*_user`) se mantienen: su política sigue pendiente (finding 2 del plan).
--
-- Orden de aplicación: primero `php artisan migrate` (crea las tablas del framework: `migrations`,
-- `sessions`, `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`
-- y `users`), y después este script. La definición de `users` es idéntica a la de la migración
-- `0001_01_01_000000_create_users_table`, así que el `IF NOT EXISTS` la convierte en no-op.
--
-- Uso: docker compose exec -T mysql mysql -ularavel -ppassword personal_finances < database/schema/01-personal-finances.sql

-- Creación de la base de datos (Opcional, descomenta si es necesario)
-- CREATE DATABASE IF NOT EXISTS personal_finance CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE personal_finance;

-- Desactivar temporalmente las verificaciones de claves foráneas para la creación limpia
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Tabla de Usuarios (Compatible con el sistema de autenticación de Laravel)
CREATE TABLE IF NOT EXISTS `users` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `email_verified_at` TIMESTAMP NULL,
  `password` VARCHAR(255) NOT NULL,
  `remember_token` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Cuentas Financieras (Efectivo, Cuentas Bancarias, Tarjetas de Crédito, etc.)
CREATE TABLE IF NOT EXISTS `accounts` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `type` VARCHAR(50) NOT NULL, -- Ej: cash, bank, card, savings
  `balance` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  `currency` VARCHAR(3) NOT NULL DEFAULT 'USD',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL,
  `deleted_at` TIMESTAMP NULL,
  CONSTRAINT `fk_accounts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Categorías de Gastos/Ingresos (Soporta jerarquía con parent_id para subcategorías)
CREATE TABLE IF NOT EXISTS `categories` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` BIGINT UNSIGNED NULL, -- NULL para categorías globales del sistema
  `name` VARCHAR(255) NOT NULL,
  `type` VARCHAR(50) NOT NULL, -- income, expense
  `parent_id` BIGINT UNSIGNED NULL,
  `color` VARCHAR(50) NULL, -- Código de color o clase para etiquetas en Filament
  `icon` VARCHAR(100) NULL, -- Nombre del icono compatible (ej. Heroicons)
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL,
  CONSTRAINT `fk_categories_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_categories_parent` FOREIGN KEY (`parent_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Transacciones Financieras (Gastos e Ingresos optimizados para Filament Resources)
CREATE TABLE IF NOT EXISTS `transactions` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `account_id` BIGINT UNSIGNED NOT NULL,
  `category_id` BIGINT UNSIGNED NULL, -- NULL: la transacción sobrevive si se elimina la categoría (D19)
  `amount` DECIMAL(12, 2) NOT NULL,
  `transaction_date` DATE NOT NULL,
  `payee` VARCHAR(255) NULL, -- Beneficiario o comercio donde se realizó el gasto
  `description` TEXT NULL,
  `receipt` VARCHAR(255) NULL, -- Ruta o referencia al comprobante adjunto
  `status` ENUM('completed', 'pending', 'cancelled') NOT NULL DEFAULT 'completed',
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL,
  `deleted_at` TIMESTAMP NULL,
  CONSTRAINT `fk_transactions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_transactions_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT, -- protege el historial: no se puede borrar una cuenta con transacciones (D19)
  CONSTRAINT `fk_transactions_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL, -- la transacción queda sin categoría en vez de borrarse (D19)
  -- Índices estratégicos para acelerar consultas, reportes y filtros del panel de Filament
  INDEX `idx_user_trans_date` (`user_id`, `transaction_date`),
  INDEX `idx_category_trans_date` (`category_id`, `transaction_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Presupuestos Mensuales por Categoría
CREATE TABLE IF NOT EXISTS `budgets` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `category_id` BIGINT UNSIGNED NOT NULL,
  `amount` DECIMAL(12, 2) NOT NULL,
  `month` TINYINT UNSIGNED NOT NULL, -- Valores del 1 al 12
  `year` SMALLINT UNSIGNED NOT NULL,  -- Ej: 2026
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL,
  CONSTRAINT `fk_budgets_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_budgets_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE RESTRICT, -- un presupuesto sin categoría no existe; y `uq_user_category_period` incluye `category_id` (D19)
  -- Restricción única para evitar duplicar el presupuesto de la misma categoría en un mismo mes/año por usuario
  CONSTRAINT `uq_user_category_period` UNIQUE (`user_id`, `category_id`, `month`, `year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reactivar las verificaciones de claves foráneas
SET FOREIGN_KEY_CHECKS = 1;
