<?php

namespace App;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    // public function registerBundles(): iterable
    // {
    //     $contents = require dirname(__DIR__) . '/config/bundles.php';
    //     foreach ($contents as $class => $envs) {
    //         if ($envs[$this->environment] ?? false) {
    //             yield new $class();
    //         }
    //     }

    //     // ADD OR ENSURE THESE BLOCKS ARE PRESENT AND CORRECTLY CONFIGURED
    //     // The default Symfony Flex setup typically handles this via config/bundles.php
    //     // but if you're directly instantiating bundles, this is important.

    //     // If you have specific bundles that *must* be loaded for dev/test:
    //     // if (in_array($this->environment, ['dev', 'test'])) {
    //     //     yield new \Symfony\Bundle\DebugBundle\DebugBundle();
    //     //     yield new \Symfony\Bundle\WebProfilerBundle\WebProfilerBundle();
    //     // }

    //     // MakerBundle is typically dev-only:
    //     // if ($this->environment === 'dev') {
    //     //     yield new \Symfony\Bundle\MakerBundle\MakerBundle();
    //     // }
    // }
}
