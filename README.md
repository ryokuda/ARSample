# 動作を確認した実行環境
* macOS Big Sur Version 11.3.1
* Xcode 12.0
* iPhone12 Pro

# 使い方
**ARSample**アプリを立ち上げて、背面カメラを撮影したい方向に向けて、
スクリーンを軽くタップしてください。
すると、カメラ画像のJPEGファイル、LiDARからの深度情報のxmlファイル、及び、
LiDARからのコンフィデンス情報のxmlファイルを、
アプリケーションコンテナのDocumentsフォルダに保存します。
ファイル名は撮影した年月日と時分秒の数字を使って
* **カメラ画像のJPEGファイル**: *yyyymmdd-hhmmss*.jpg
* **深度情報のxmlファイル**: *yyyymmdd-hhmmss*.dpt
* **コンフィデンス情報のxmlファイル**: *yyyymmdd-hhmmss*.cnf

保存したファイルを読み出すにはXCodeを使ってデバイスのコンテナ情報を読み出す必要があります。  

操作方法：
1. XCodeを立ち上げてiPhoneデバイスを接続する
2. XCodeの**Window**メニューから**Device and Simulators**を選択します
3. **Devices**から目的のiPhoneデバイスを選択します
4. **INSTALLED APPS**の中から**ARSample**を選択します
5. その下の設定アイコン（歯車アイコン）をクリックし **Download Container...** を実行し、コンテナ情報をmacのファイルとして保存します
6. 保存したファイルをFinderで右クリックし**Show Package Contents**を選びます
7. Finderの新たなウインドウが現れるので、**AppData** => **Documents**を開くと保存されたファイルを見ることができます

深度情報のxmlファイルの内容は、次のように浮動小数点数の一次元配列になっています。

```xml:yyyymmdd-hhmmss.dpt
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <real>3.669921875</real>
    <real>4.07421875</real>
    <real>4.015625</real>
    <real>4.03515625</real>
    <real>4.20703125</real>
    .... 合計49,152 (=256*192) 行続く ....
```

これらの数値の単位はメートルで、幅256、高さ192の二次元配列を一次元に並べたものであり、原点（左上）の要素を
先頭にして幅方向（x軸方向）の256サンプルの塊が192回繰り返して現れるフォーマットになっています。

コンフィデンス情報のxmlファイルの内容は、次のように整数の一次元配列になっています。
要素が並ぶ順番は深度情報のxmlファイルと同じです。

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <integer>0</integer>
    <integer>0</integer>
    <integer>0</integer>
    <integer>0</integer>
    <integer>0</integer>
    <integer>0</integer>
    <integer>0</integer>
```

現れる数値は深度情報の確度の高低を表わす0〜2の整数で、2:確度高、1:確度中、0:確度低の意味と推測されます。
iPhone 12 ProのLiDARから出力される数値を見ていると、深度が5.5m未満ならコンフィデンスは2、
5.5m以上で6m未満ならコンフィデンスは1、6m以上ならコンフィデンスは0になっているようです。

# ソースコードに関するメモ
## 大元のソースコード
**ASSample**のソースコードは次のようにして得ることができるArgumented Reality Appのサンプルコードを元にしています。  
サンプルコードの生成方法
1. XCodeの**File**メニューから**New**=>**Project**を実行します
2. **iOS**のアプリケーションメニューから**Argumented Reality App**を選択し**Next**に進みます
3. Product Nameを付け、Content Technologyの欄で**Metal**を選択して**Next**に進み、プロジェクトを生成します

## ソースコードの変更点
このサンプルアプリの機能は、
スクリーンをタップした時にカメラ位置に立方体の仮想物体（ARAnchor）を挿入し、
以後、ARKit（拡張現実機能）を使用して挿入された物体が３次元空間の挿入された位置に表示し続けるというものです。
**ARSample**アプリはLiDARからの深度情報を取得するためにだけARKitを使用しており、アプリ内部で実行されているトラッキングの機能は全く使っていません。  
ソースコードの変更はファイル**ViewController.swift**のみに限られています。  

スクリーンがタップされた時に仮想物体を挿入する関数、
```swift:ViewController.swift
@objc
func handleTap(gestureRecognize: UITapGestureRecognizer) {
```
をコメントアウトし、代わりに、画像や深度情報をファイルとして保存する関数
```swift:ViewController.swift
@objc
func checkTap(gestureRecognize: UITapGestureRecognizer) {
```
を挿入しています。  

スクリーンがタップされた時に`checkTap`が呼び出されるように、Gesture Recognizer生成部分を
```swift:ViewController.swift
/*
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
view.addGestureRecognizer(tapGesture)
*/
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.checkTap(gestureRecognize:)))
view.addGestureRecognizer(tapGesture)
```
のように変更しています。  

関数`checkTap`の内部の処理は、最初に現在の日付と時間を取得して保存するファイルの名前を生成します。
```swift:ViewController.swift
// get time stamp and create file names
let dt = Date()
let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "jp_JP" )
dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
let timeStamp = dateFormatter.string(from: dt)

let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let jpegFileName = documentPath.appendingPathComponent( timeStamp+".jpg" )
let depthFileName = documentPath.appendingPathComponent( timeStamp+".dpt" )
let confidenceFileName = documentPath.appendingPathComponent( timeStamp+".cnf" )
```

次に、カメラ画像をJPEGファイルに保存します。
```swift:ViewController.swift
// save camera image to JPEG file
let image = currentFrame.capturedImage
// print( "Camera Image width:"+String(CVPixelBufferGetWidth(image))+" height:"+String(CVPixelBufferGetHeight(image))) // 1920 x 1440
let uiimage = UIImage( pixelBuffer: image )
var width = Int(uiimage!.size.width)
var height = Int(uiimage!.size.height)
// print( "UIImage width:"+String(width)+" height:"+String(height)) // 1920 x 1440
let jpgImage = uiimage!.jpegData(compressionQuality:0.4)
do {
    try jpgImage?.write( to: jpegFileName, options: .atomic)
} catch {
    print( "cannot write jpeg data" )
    return
}
```
カメラ画像は、`ARSession.currentFrame`オブジェクトの
`capturedImage`オブジェクトに入っています。
このオブジェクトの型は`CVPixelBuffer`でありJPEGファイルに変換するために
一旦`UIImage`型に変換しています。

この変換に使うコード（`UIImage`のコンストラクタ）として、
```swift:ViewController.swift
extension UIImage {     // for tranforming CVPixelBuffer to UIImage
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}
```
のように`UIImage`クラスを拡張しています。  

次に、LiDARからの深度情報を取得してファイルに保存する部分です。
大元のソースコードではLiDARが出力する情報を取得できません。
LiDARからのデータを取得できるようにするには、`ARSession`のコンフィグレーションに置いて
次のコード
```swift:ViewContrtoller.swift
// Create a session configuration
let configuration = ARWorldTrackingConfiguration()
configuration.frameSemantics = [
                    .sceneDepth,            // raw output from LiDAR
                    .smoothedSceneDepth     // filtered output from LiDAR
                ]
```
を使って、`.sceneDepth`を指定する必要があります。
`.smoothedSceneDepth`は、深度情報が画像フレーム間でスムーズになるようにフィルタを掛けた深度情報を
取得できるようにする指定ですが、このプログラムではデータの取得はしていません。  

深度情報を取得してファイルに保存する部分のコードは次の通りです。
```swift:ViewController.swift
// save depth data to a file
guard let depthMap = currentFrame.sceneDepth?.depthMap else { return }
CVPixelBufferLockBaseAddress(depthMap,.readOnly) // enable CPU can read the CVPixelBuffer
height = CVPixelBufferGetHeight( depthMap ) // 192 pixel
// let bytesPerRow = CVPixelBufferGetBytesPerRow( depthMap ) // 1024 = 256 pixel X 4 bytes
width = CVPixelBufferGetWidth( depthMap ) // 256 pixcel
// let planes = CVPixelBufferGetPlaneCount( depthMap ) // 0
// let dataSize = CVPixelBufferGetDataSize( depthMap ) // 196,608 = 256 pixel X 192 pixel X 4 bytes

var base = CVPixelBufferGetBaseAddress( depthMap )
var bindPtr = base?.bindMemory(to: Float32.self, capacity: width * height )
var bufPtr = UnsafeBufferPointer(start:bindPtr, count: width * height)
let depthArray = Array(bufPtr)
//print( depthArray )
do {
    try (depthArray as NSArray).write( to:depthFileName, atomically: false ) // written in xml text format
} catch {
    print( "cannot write depth data" )
}
CVPixelBufferUnlockBaseAddress(depthMap,.readOnly) // Free buffer
```

深度情報は32bitの単精度浮動小数点数であり、`ARSessio.currentFrame`オブジェクトの
`sceneDepth.depthMap`オブジェクトに入っています。
ここから深度情報を取得するやり方は、[iOSデバイス上のアプリケーションコンテナの内容を確認する方法](https://qiita.com/1024chon/items/74da8d63a8959a8192f5)を参考にしています。  

同様にコンフィデンス情報も取得します。
```swift:ViewController.swift
// save confidence data to a file
guard let confidenceMap = currentFrame.sceneDepth?.confidenceMap else { return }
CVPixelBufferLockBaseAddress(confidenceMap,.readOnly) // enable CPU can read the CVPixelBuffer
height = CVPixelBufferGetHeight( confidenceMap ) // 192 pixel
//let bytesPerRow = CVPixelBufferGetBytesPerRow( confidenceMap ) // 1024 = 256 pixel X 1 bytes
width = CVPixelBufferGetWidth( confidenceMap ) // 256 pixcel
// let planes = CVPixelBufferGetPlaneCount( confidenceMap ) // 0
// let dataSize = CVPixelBufferGetDataSize( confidenceMap ) // 49,152 = 256 pixel X 192 pixel X 1 bytes
// let type = CVPixelBufferGetPixelFormatType( confidenceMap )

base = CVPixelBufferGetBaseAddress( confidenceMap )
let bindPtr2 = base?.bindMemory(to: UInt8.self, capacity: width * height )
let bufPtr2 = UnsafeBufferPointer(start:bindPtr2, count: width * height)
let confidenceArray = Array(bufPtr2)
//print( confidenceArray )
do {
    try (confidenceArray as NSArray).write( to:confidenceFileName, atomically: false ) // written in xml text format
} catch {
    print( "cannot write depth data" )
}
CVPixelBufferUnlockBaseAddress(confidenceMap,.readOnly) // Free buffer
```
コンフィデンス情報は符号無し１バイト整数`UInt8`です。
