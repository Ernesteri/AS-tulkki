<?php
// Julkinen sovelluskuori. Kilpailutiedot haetaan erikseen tunnistetusta rajapinnasta.
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
readfile(__DIR__ . '/index.html');
