<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class GeocodingService
{
    public function geocode(string $address): ?array
    {
        $provider = strtolower((string) config('services.geocoding.provider', 'nominatim'));

        return match ($provider) {
            'nominatim' => $this->nominatimForward($address),
            'google' => $this->googleForward($address),
            default => throw new RuntimeException('Fournisseur de géocodage non configuré.'),
        };
    }

    public function reverse(float $latitude, float $longitude): ?string
    {
        $provider = strtolower((string) config('services.geocoding.provider', 'nominatim'));

        return match ($provider) {
            'nominatim' => $this->nominatimReverse($latitude, $longitude),
            'google' => $this->googleReverse($latitude, $longitude),
            default => throw new RuntimeException('Fournisseur de géocodage non configuré.'),
        };
    }

    private function nominatimForward(string $address): ?array
    {
        $response = Http::acceptJson()
            ->withHeaders(['User-Agent' => config('services.geocoding.user_agent')])
            ->timeout((int) config('services.geocoding.timeout', 8))
            ->get('https://nominatim.openstreetmap.org/search', [
                'q' => $address,
                'format' => 'jsonv2',
                'limit' => 1,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Le service de géocodage est indisponible.');
        }

        $result = $response->json('0');
        if (! is_array($result) || ! isset($result['lat'], $result['lon'])) {
            return null;
        }

        return [
            'latitude' => (float) $result['lat'],
            'longitude' => (float) $result['lon'],
            'address' => $result['display_name'] ?? $address,
        ];
    }

    private function nominatimReverse(float $latitude, float $longitude): ?string
    {
        $response = Http::acceptJson()
            ->withHeaders(['User-Agent' => config('services.geocoding.user_agent')])
            ->timeout((int) config('services.geocoding.timeout', 8))
            ->get('https://nominatim.openstreetmap.org/reverse', [
                'lat' => $latitude,
                'lon' => $longitude,
                'format' => 'jsonv2',
            ]);

        if ($response->failed()) {
            return null;
        }

        return $response->json('display_name');
    }

    private function googleForward(string $address): ?array
    {
        $response = Http::acceptJson()
            ->timeout((int) config('services.geocoding.timeout', 8))
            ->get('https://maps.googleapis.com/maps/api/geocode/json', [
                'address' => $address,
                'key' => config('services.geocoding.api_key'),
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Le service de géocodage est indisponible.');
        }

        $result = $response->json('results.0');
        if (! is_array($result) || ! isset($result['geometry']['location'])) {
            return null;
        }

        return [
            'latitude' => (float) $result['geometry']['location']['lat'],
            'longitude' => (float) $result['geometry']['location']['lng'],
            'address' => $result['formatted_address'] ?? $address,
        ];
    }

    private function googleReverse(float $latitude, float $longitude): ?string
    {
        $response = Http::acceptJson()
            ->timeout((int) config('services.geocoding.timeout', 8))
            ->get('https://maps.googleapis.com/maps/api/geocode/json', [
                'latlng' => "$latitude,$longitude",
                'key' => config('services.geocoding.api_key'),
            ]);

        if ($response->failed()) {
            return null;
        }

        return $response->json('results.0.formatted_address');
    }
}
