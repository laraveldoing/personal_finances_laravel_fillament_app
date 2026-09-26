<?php

namespace Tests\Unit;

use App\Enums\AccountType;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class AccountTypeTest extends TestCase
{
    #[Test]
    public function it_defines_the_expected_account_types(): void
    {
        $this->assertSame([
            'cash',
            'bank',
            'card',
            'savings',
        ], array_column(AccountType::cases(), 'value'));
    }

    #[Test]
    public function it_can_be_instantiated_from_valid_strings(): void
    {
        $this->assertSame(AccountType::Cash, AccountType::from('cash'));
        $this->assertSame(AccountType::Bank, AccountType::from('bank'));
        $this->assertSame(AccountType::Card, AccountType::from('card'));
        $this->assertSame(AccountType::Savings, AccountType::from('savings'));
    }
}
