<?php

namespace Tests\Unit;

use App\Enums\TransactionStatus;
use PHPUnit\Framework\TestCase;

class TransactionStatusTest extends TestCase
{
    /**
     * The stored values are a contract with `transactions.status` (D21): renaming or reordering them
     * silently would break every existing row, so they are pinned here on purpose.
     */
    public function test_the_three_stored_values_are_stable(): void
    {
        $this->assertSame(
            ['completed', 'pending', 'cancelled'],
            array_map(fn (TransactionStatus $status) => $status->value, TransactionStatus::cases()),
        );
    }

    public function test_a_stored_value_resolves_back_to_its_case(): void
    {
        $this->assertSame(TransactionStatus::Completed, TransactionStatus::from('completed'));
        $this->assertSame(TransactionStatus::Pending, TransactionStatus::tryFrom('pending'));
        $this->assertSame(TransactionStatus::Cancelled, TransactionStatus::tryFrom('cancelled'));
        $this->assertNull(TransactionStatus::tryFrom('refunded'));
    }
}
