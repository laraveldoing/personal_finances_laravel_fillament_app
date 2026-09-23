<?php

return [
    /*
    | Credentials for the single Filament panel administrator, seeded by
    | Database\Seeders\AdminUserSeeder. Values come from the environment so
    | no password ever lands in the code or in shell history.
    */
    'name' => env('FILAMENT_ADMIN_NAME'),
    'email' => env('FILAMENT_ADMIN_EMAIL'),
    'password' => env('FILAMENT_ADMIN_PASSWORD'),
];
