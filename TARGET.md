# Entrega mobile

Esta branch é a entrega Flutter para Android e iOS. Ela mantém a interface responsiva compartilhada com a web e adiciona uma automação que analisa, testa e gera o APK de release a cada push em `app`.

## Executar

```bash
flutter pub get
flutter run -d android
```

## Gerar pacotes

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

O build iOS exige macOS/Xcode. Para distribuição em loja, configure os certificados e a assinatura do projeto antes de gerar o pacote final.
