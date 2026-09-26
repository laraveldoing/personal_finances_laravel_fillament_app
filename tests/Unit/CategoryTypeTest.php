<?php

namespace Tests\Unit;

use App\Enums\CategoryType;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class CategoryTypeTest extends TestCase
{
    #[Test]
    public function it_defines_the_expected_category_types(): void
    {
        $this->assertSame([
            'income',
            'expense',
        ], array_column(CategoryType::cases(), 'value'));
    }

    #[Test]
    public function it_can_be_instantiated_from_valid_strings(): void
    {
        $this->assertSame(CategoryType::Income, CategoryType::from('income'));
        $this->assertSame(CategoryType::Expense, CategoryType::from('expense'));
    }
}
