<?php

namespace Tests\Unit;

use App\Enums\AccountType;
use App\Enums\CategoryType;
use App\Enums\TransactionStatus;
use App\Models\Account;
use App\Models\Budget;
use App\Models\Category;
use App\Models\Transaction;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DomainModelCastsTest extends TestCase
{
    #[Test]
    public function account_casts_attributes_correctly(): void
    {
        $account = new Account([
            'type' => 'bank',
            'balance' => '123.456',
            'is_active' => 1,
        ]);

        $this->assertSame(AccountType::Bank, $account->type);
        $this->assertSame('123.46', $account->balance);
        $this->assertTrue($account->is_active);
    }

    #[Test]
    public function category_casts_type_to_enum(): void
    {
        $category = new Category([
            'type' => 'expense',
        ]);

        $this->assertSame(CategoryType::Expense, $category->type);
    }

    #[Test]
    public function transaction_casts_attributes_correctly(): void
    {
        $tx = new Transaction([
            'status' => 'pending',
            'amount' => '-45.678',
            'transaction_date' => '2026-09-25',
        ]);

        $this->assertSame(TransactionStatus::Pending, $tx->status);
        $this->assertSame('-45.68', $tx->amount);
        $this->assertInstanceOf(Carbon::class, $tx->transaction_date);
    }

    #[Test]
    public function budget_casts_attributes_correctly(): void
    {
        $budget = new Budget([
            'amount' => '500.000',
            'month' => '9',
            'year' => '2026',
        ]);

        $this->assertSame('500.00', $budget->amount);
        $this->assertSame(9, $budget->month);
        $this->assertSame(2026, $budget->year);
    }
}
