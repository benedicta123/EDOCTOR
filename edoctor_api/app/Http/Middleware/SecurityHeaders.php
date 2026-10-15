<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    /**
     * Handle an incoming request and enforce defensive HTTP security headers.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        // Anti-MIME Sniffing
        $response->headers->set('X-Content-Type-Options', 'nosniff');

        // Anti-Clickjacking : autorise uniquement l'encadrement par le même domaine
        $response->headers->set('X-Frame-Options', 'SAMEORIGIN');

        // Protection XSS historique pour navigateurs plus anciens
        $response->headers->set('X-XSS-Protection', '1; mode=block');

        // Contrôle du Referrer pour protéger la vie privée des URLs de santé
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');

        // Restrictions des APIs du navigateur
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(self)');

        // HSTS (HTTP Strict Transport Security)
        if ($request->isSecure() || app()->environment('production')) {
            $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
        }

        // Content-Security-Policy (CSP)
        if ($request->is('api/*')) {
            // Pour l'API JSON pure, interdire formellement toute exécution ou framing
            $response->headers->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none';");
        } else {
            $response->headers->set(
                'Content-Security-Policy',
                "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https: blob:; connect-src 'self' https:; frame-ancestors 'self';"
            );
        }

        return $response;
    }
}
