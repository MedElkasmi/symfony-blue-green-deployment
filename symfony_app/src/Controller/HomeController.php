<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class HomeController extends AbstractController
{
    #[Route('/health', name: 'app_health')]
    public function index(): Response
    {
        // In a real application, you might check database connection,
        // external services, etc., here.
        // For this demo, just returning a 200 OK is sufficient.
        return new Response('OK', Response::HTTP_OK);
    }
}
