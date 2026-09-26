<?php

namespace App\Enums;

/**
 * The values `categories.type` accepts — the classification every transaction and budget is grouped
 * by. It is deliberately *not* the source of a transaction's sign: that belongs to
 * `transactions.amount` (D24).
 */
enum CategoryType: string
{
    case Income = 'income';

    case Expense = 'expense';
}
