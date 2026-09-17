import QtQuick
import Quickshell
import "WindowRegistry.js" as LayoutMath

// Saf hesaplama bileşeni: verilen genişlik/yükseklik ve kullanıcının ölçek
// tercihinden bir baseScale üretir. On ayrı widget'ta örnekleniyor, o yüzden
// burada hiçbir process/timer olmamalı — uiScale Settings singleton'ından
// geliyor, dosyayı tek bir yer izliyor.
Item {
    id: root
    visible: false

    property real currentWidth: 1920.0
    property real currentHeight: 1080.0
    readonly property real uiScale: Settings.uiScale

    property real baseScale: LayoutMath.getScale(currentWidth, currentHeight, uiScale)

    function s(val) {
        return LayoutMath.s(val, baseScale);
    }
}
