<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class HomeController extends AbstractController
{
    #[Route('/home', name: 'app_home')]
    public function index(): Response
    {

        // Get the application version from an environment variable
        $appVersion = $_ENV['APP_VERSION'] ?? 'Unknown';

        return $this->render('home/index.html.twig', [
            'app_version' => $appVersion,
        ]);
    }
}
