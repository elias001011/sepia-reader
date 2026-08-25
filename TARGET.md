# Entrega web

Esta branch é a entrega web/PWA do Sépia. Ela mantém a mesma experiência de biblioteca, editor dividido e modo leitura, com importação e download nativos do navegador.

## Executar

```bash
flutter pub get
flutter run -d chrome
```

## Gerar a versão estática

```bash
flutter build web --release
```

O conteúdo de `build/web` pode ser publicado em qualquer hospedagem estática. A automação desta branch analisa, testa e disponibiliza esse diretório como artefato a cada push em `web`.
