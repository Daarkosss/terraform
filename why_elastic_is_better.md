# Dlaczego wybrałem Elastic Beanstalk, a nie Fargate?

## Wstęp
Najbardziej ogólnie, ku wyborze Elastic Beanstalk skłania potrzeba prostego i automatycznego wdrażania aplikacji. 

## Przyczyny
- Elastic Beanstalk buduje aplikację za nas. My przesyłamy kod, a Elastic Beanstalk zajmuje się resztą.
- Elastic Beanstalk obsługuje tylko niektóre języki programowania aplikacji i platformy wdrożeniowe. Fargate może uruchomić dowolny typ aplikacji, która może działać jako kontener, co oznacza praktycznie każdą aplikację. W praktyce jednak, używając Elastic Beanstalk z platformą Dockera, możemy wdrożyć dowolną aplikację, niezależnie od użytych technologii, potrzebujemy jedynie dobrze skonfigurowany Dockerfile.
- Elastic Beanstalk automatycznie zarządza szczegółami infrastruktury, takimi jak skalowanie, monitorowanie i aktualizacje.
- Elastic Beanstalk pobiera opłaty za instancje EC2 wybrane do hostowania aplikacji. Z kolei Fargate pobiera opłatę godzinową za każdy wirtualny procesor używany przez Twoją aplikację, a także za ilość zużywanej przez nią pamięci i miejsca.

## Moja droga do wdrożenia apki
Elastic Beanstalk, w przeciwieństwie do Fargate, oferuje również możliwość wdrożenia aplikacji bez kodu terraform. Tak napierw zrobiłem: wszystko wyklikałem aby stworzyć environment z platformą Dockera. Następnie wrzuciłem zipa z kodem źródłowym i plikiem Dockerfile. Potem tylko ustawiłem zmienne środowiskowe dla frontendu, aby miał odpowiednio ustawionego hosta do API i zadziałało. 

Następnie zrobiłem to bardzo podobnie ale w pliku terraform i też udało się wdrożyć aplikację. 