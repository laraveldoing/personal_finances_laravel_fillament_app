<?php

namespace App\Models;

use App\Enums\TransactionStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'user_id',
    'account_id',
    'category_id',
    'amount',
    'transaction_date',
    'payee',
    'description',
    'receipt',
    'status',
])]
class Transaction extends Model
{
    use SoftDeletes;

    /**
     * `amount` is signed (positive = income, negative = expense; D24) and `status` is cast to the
     * enum that holds the list (D21) — reading a value the enum does not define fails loudly instead
     * of silently degrading, which is the point of moving the list out of the database.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'transaction_date' => 'date',
            'status' => TransactionStatus::class,
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * The account is required and never null: `fk_transactions_account` is RESTRICT (D19).
     *
     * @return BelongsTo<Account, $this>
     */
    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /**
     * Nullable since D19: a transaction survives its category, uncategorized.
     *
     * @return BelongsTo<Category, $this>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }
}
