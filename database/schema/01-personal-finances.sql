-- Esquema de dominio de la aplicación de finanzas personales.
--
-- Origen: script entregado por la persona responsable del proyecto (2026-09-22). Se aplicó tal cual
-- sobre la base de datos `personal_finances` del contenedor MySQL definido en `docker-compose.yml`.
-- Las dos líneas comentadas de abajo (creación y uso de la base) son opcionales y usan ya el nombre
-- en plural (D25); no se descomentan porque la base ya existe con ese nombre.
--
-- Cambio de semántica (2026-09-23, decisión D19 en `/plans/schema-import-and-filament.md`): las
-- reglas `ON DELETE` de tres claves foráneas dejaron de ser `CASCADE` para proteger el historial
-- financiero — `fk_transactions_account` → `RESTRICT`, `fk_transactions_category` → `SET NULL`
-- (por eso `transactions.category_id` es NULL) y `fk_budgets_category` → `RESTRICT`.
--
-- Cambio de semántica (2026-09-25, decisión D20 en `/plans/user-delete-policy.md`): los cuatro
-- `fk_*_user` dejaron de ser `CASCADE` y pasaron a `RESTRICT`, así que un borrado duro de `users`
-- ya no puede destruir el historial financiero del usuario — tampoco por SQL directo. La operación
-- soportada pasa a ser el borrado lógico (SoftDeletes): la columna `users.deleted_at` la añade la
-- migración `2026_09_25_000000_add_deleted_at_to_users_table`, no este script, porque `users`
-- pertenece a las migraciones del framework. Un purgado real exige un camino explícito que borre
-- en orden de dependencias; eso queda como hueco documentado, no accidental.
--
-- Convenciones fijadas (2026-09-25, decisiones D21–D24 en `/plans/schema-findings-3-8.md`):
--   * `transactions.status` es `VARCHAR(20) NOT NULL DEFAULT 'completed'` (D21): la lista de valores
--     (`completed`, `pending`, `cancelled`) vive en `App\Enums\TransactionStatus`, no en el esquema.
--   * `budgets.month` está entre 1 y 12 y `budgets.year` entre 1900 y 2999 (D23, restricciones
--     `chk_budgets_month` y `chk_budgets_year`).
--   * `transactions.amount` lleva signo (D24): positivo = ingreso, negativo = gasto, nunca 0
--     (restricción `chk_transactions_amount_not_zero`); `categories.type` clasifica la transacción,
--     no decide su signo.
--   * Las dos sentencias `SET FOREIGN_KEY_CHECKS` se eliminaron (D22): el orden de creación ya respeta
--     las dependencias, y sin ellas un script aplicado en el orden equivocado falla en lugar de crear
--     referencias colgantes.
-- Las transferencias entre cuentas siguen sin esquema; su forma está registrada en ese mismo plan
-- (D26).
--
-- Orden de aplicación: primero `php artisan migrate` (crea las tablas del framework: `migrations`,
-- `sessions`, `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`
-- y `users`), y después este script. La definición de `users` es idéntica a la de la migración
-- `0001_01_01_000000_create_users_table`, así que el `IF NOT EXISTS` la convierte en no-op.
--
-- Uso: docker compose exec -T mysql mysql -ularavel -ppassword personal_finances < database/schema/01-personal-finances.sql

-- Creación de la base de datos (Opcional, descomenta si es necesario)
-- CREATE DATABASE IF NOT EXISTS personal_finances CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE personal_finances;

-- 1. Tabla de Usuarios (Compatible con el sistema de autenticación de Laravel)
-- Nota (D20): la columna `deleted_at` del borrado lógico la añade la migración
-- `2026_09_25_000000_add_deleted_at_to_users_table`, no se declara aquí porque este bloque sólo
-- actúa como no-op sobre la tabla que ya crearon las migraciones (`IF NOT EXISTS`).
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
  CONSTRAINT `fk_accounts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT -- D20: la cuenta impide el borrado duro del usuario
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
  CONSTRAINT `fk_categories_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT, -- D20: igual que `fk_accounts_user` (sólo afecta a categorías propias; `user_id` NULL = global)
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
  `status` VARCHAR(20) NOT NULL DEFAULT 'completed', -- D21: la lista de valores vive en `App\Enums\TransactionStatus`
  `created_at` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NULL,
  `deleted_at` TIMESTAMP NULL,
  CONSTRAINT `fk_transactions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT, -- D20: un borrado duro del usuario se rechaza mientras existan sus transacciones
  CONSTRAINT `fk_transactions_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT, -- protege el historial: no se puede borrar una cuenta con transacciones (D19)
  CONSTRAINT `fk_transactions_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL, -- la transacción queda sin categoría en vez de borrarse (D19)
  CONSTRAINT `chk_transactions_amount_not_zero` CHECK (`amount` <> 0), -- D24: el signo indica ingreso (+) o gasto (-); 0 no es un movimiento
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
  CONSTRAINT `fk_budgets_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT, -- D20: igual que las otras tres
  CONSTRAINT `fk_budgets_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE RESTRICT, -- un presupuesto sin categoría no existe; y `uq_user_category_period` incluye `category_id` (D19)
  CONSTRAINT `chk_budgets_month` CHECK (`month` BETWEEN 1 AND 12), -- D23: `TINYINT UNSIGNED` por sí solo aceptaría 13
  CONSTRAINT `chk_budgets_year` CHECK (`year` BETWEEN 1900 AND 2999), -- D23
  -- Restricción única para evitar duplicar el presupuesto de la misma categoría en un mismo mes/año por usuario
  CONSTRAINT `uq_user_category_period` UNIQUE (`user_id`, `category_id`, `month`, `year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
