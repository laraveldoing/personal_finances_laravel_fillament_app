<?php

namespace App\Enums;

/**
 * The values `transactions.status` can hold.
 *
 * The column is a `VARCHAR(20)` and not a MySQL `ENUM` (D21 in `/plans/schema-findings-3-8.md`), so
 * this enum — not the database — is the single source of truth for the list: adding a status means
 * adding a case here, with no `ALTER TABLE`.
 */
enum TransactionStatus: string
{
    case Completed = 'completed';

    case Pending = 'pending';

    case Cancelled = 'cancelled';
}
