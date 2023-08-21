# mangahub
mangahub

1. Run: flutter gen-l10n

2. https://www.flutterbeads.com/change-app-name-in-flutter/?expand_article=1

3. https://www.flutterbeads.com/change-app-launcher-icon-flutter/?expand_article=1
    --> flutter pub run flutter_launcher_icons:main
4. Change Application ID: 
    pubspec.yaml
        flutter:
            name: com.example.myapp
        Bạn có thể thay đổi giá trị của thuộc tính name thành Application ID mới mà bạn muốn sử dụng. Sau khi thay đổi, bạn cần chạy lại lệnh flutter packages get để cập nhật các phụ thuộc và sau đó xây dựng lại ứng dụng để áp dụng thay đổi Application ID
5.  turn off showNSFW -> model > setting.dart
    hide in UI: