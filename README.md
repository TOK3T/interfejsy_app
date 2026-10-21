# Panel czujników

Aplikacja Flutter odwzorowująca panel z `gui.py`: pokazuje odczyty z Pico WH,
pozwala sterować dwoma wyjściami cyfrowymi i dwoma wyjściami PWM oraz łączy się
z urządzeniem w tej samej sieci Wi-Fi.

## Połączenie sieciowe

Na Raspberry Pi uruchom most poleceniem `python bridge.py` z folderu
`Interfejsy`. Zmiany w `connect.py` dodają most UDP: Pi odbiera odczyty Pico na
porcie `5005`, a sterowanie z telefonu na porcie `5006`. Adres Pico jest
wykrywany z pakietów pomiarowych; adres telefonu — z pakietu sterowania. Pi
przekazuje odczyty do telefonu i polecenia do Pico, więc urządzenia nie
komunikują się bezpośrednio. Aplikację Python z oknem można nadal uruchamiać
poleceniem `python main.py`.

W aplikacji wpisz aktualny adres IPv4 Raspberry Pi i wybierz **Połącz**.
Aplikacja nasłuchuje pakietów UDP na porcie `5005` i wysyła sterowanie na port
`5006`. Pakiety pomiarowe muszą pochodzić z wpisanego adresu Pi.

Pomiary przekazywane przez Pi mają format JSON:

```json
{
  "Day_State": 1,
  "Tryb": 1,
  "temperatura": 21.5,
  "wilgotnosc": 48.2,
  "wilgotnosc_gleby": 45,
  "poziom_swiatla": 750,
  "stan_wody": 1
}
```

Telefon, Raspberry Pi i Pico muszą być w tej samej sieci Wi-Fi. W zaporze
systemowej Raspberry Pi zezwól na przychodzące pakiety UDP na portach `5005`
i `5006`.

Most na Pi rozgłasza w sieci swój aktualny adres IP. Zaktualizuj i wgraj na
Pico szkic `Interfejsy/Kod_Pico/Kod_Pico.ino`, aby Pico wykrywało Pi z tego
komunikatu zamiast używać stałego `IP_MALINKI`. Po tej jednorazowej zmianie
zmiana adresu Pi nie wymaga ponownego wgrywania programu Pico. W aplikacji
Flutter nadal wpisujesz aktualny adres Pi, aby telefon łączył się wyłącznie z
nim.

## Uruchomienie

```sh
flutter pub get
flutter run
```

## Testy

```sh
flutter test
```
