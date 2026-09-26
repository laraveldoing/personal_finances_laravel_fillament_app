<?php

namespace App\Enums;

/**
 * The values `accounts.type` accepts.
 *
 * The column is a `VARCHAR(50)` and the database does not restrict it, so this enum is what keeps the
 * panel's options, its validation and the model cast in step — the same reasoning D21 used for the
 * transaction status.
 */
enum AccountType: string
{
    case Cash = 'cash';

    case Bank = 'bank';

    case Card = 'card';

    case Savings = 'savings';
}
