//
//  ContentView.swift
//
//  Created by miwa on 2023/11/25.
//  Modified by Yos 2024
//

import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
	private let speechSynthesizer = SpeechSynthesizer()
	private let speechRecognizer = SpeechRecognizer()
	@State private var response = ""
	@State private var responseTimer:Timer? = nil
	@State private var responseInterval = 2.0

	private var instruction: String {
//        "Transcript of a dialog, where the User interacts with an AI Assistant named Alan. Alan is helpful, kind, honest, good at writing, and never fails to answer the User's requests immediately and with precision."
//		"以下は会話の書き起こしで、ユーザはHoaというAIアシスタントと会話しています。Hoaは優しく、正直で、役立ち、文章がうまく、決してユーザのリクエストに応えることに失敗せず、常に正確です。ユーモアもあります。Hoaはハワイ語で仲間という意味です。"
		"以下は会話の書き起こしで、ユーザはHoaというAIアシスタントと会話しています。Hoaはユーザのリクエストを正確に解釈して、最終的には次の選択肢のどれか１つを回答します。それ以外の回答はしません。選択肢は「上」、「下」、「右」、「左」、「奥」、「手前」です。"
	}
	private var chatExample: [LlamaState.ChatLog.Message] {
		[
			.init(role: .user, message: "あげて"),
			.init(role: .ai, message: "上"),
			.init(role: .user, message: "さげて"),
			.init(role: .ai, message: "下"),
			.init(role: .user, message: "向こうへ"),
			.init(role: .ai, message: "奥"),
			.init(role: .user, message: "こちらに持ってきて"),
			.init(role: .ai, message: "手前"),
			.init(role: .user, message: "右側へ移動"),
			.init(role: .ai, message: "右"),
			.init(role: .user, message: "左へ移動"),
			.init(role: .ai, message: "左"),
			.init(role: .user, message: "アップ"),
			.init(role: .ai, message: "上"),
			.init(role: .user, message: "ダウン"),
			.init(role: .ai, message: "下"),
			.init(role: .user, message: "高いところ"),
			.init(role: .ai, message: "上"),
			.init(role: .user, message: "低い所"),
			.init(role: .ai, message: "下"),
		]
	}
	@State private var message: String = ""
	@State private var lastMessage: String = ""
	@StateObject private var model = LlamaState()

	var body: some View {
		VStack {
			HStack {
				TextField("Insert prompt", text: $message)
					.textFieldStyle(.roundedBorder)
				Button(action: {
					self.speechRecognizer.startRecognition()
				}) {
					Text("音声入力開始")
				}
				.padding()

				Button(action: {
					self.speechRecognizer.stopRecognition()
				}) {
					Text("音声入力停止")
				}
				.padding()
			}
			HStack {
				Button {
					guard !self.message.isEmpty else {
						return
					}
					self.model.addChatMessage(message, instruction: instruction, example: chatExample, userMessagePrefix: "User:", aiMessagePrefix: "Hoa:")
					self.speechRecognizer.newLine()
					message = ""
				} label: {
					Label {
						Text("Generate")
					} icon: {
						Image(systemName: "circle.hexagongrid.fill")
							.foregroundStyle(.conicGradient(AnyGradient(Gradient(colors: [.yellow, .blue])), angle: Angle(degrees: 90)))
					}
				}
				.keyboardShortcut(.return, modifiers: .command)
				if self.model.isGenerating {
					Button("Cancel", systemImage: "stop.circle") {
						self.model.stopGenerationTask()
					}
				} else {
					Button("Reset", systemImage: "repeat") {
						self.model.refreshContext()
						message = ""
					}
				}
			}
			ScrollView {
				ScrollViewReader { proxy in
					VStack(alignment: .leading) {
						ForEach(self.model.chatLog.messages) { message in
							HStack(alignment: .top) {
								let (systemImage, backgroundCornerRadii, backgroundColor): (String, RectangleCornerRadii, Color) = switch message.role {
								case .system:
									("info.bubble", .init(topLeading: 0, bottomLeading: 10, bottomTrailing: 10, topTrailing: 10), .gray)
								case .ai:
									("poweroutlet.type.b", .init(topLeading: 0, bottomLeading: 10, bottomTrailing: 10, topTrailing: 10), .orange)
								case .user:
									("person.fill", .init(topLeading: 0, bottomLeading: 10, bottomTrailing: 10, topTrailing: 10), .green)
								}
								Image(systemName: systemImage)
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 25)
								Text(message.message)
									.textSelection(.enabled)
									.padding()
									.background {
										UnevenRoundedRectangle(cornerRadii: backgroundCornerRadii)
											.fill(backgroundColor)
									}
							}
							.id(message.id)
						}
					}
					.onChange(of: self.model.chatLog.messages.count) { _ in
						proxy.scrollTo(self.model.chatLog.messages.last?.id, anchor: .bottom)
					}
					.onChange(of: self.model.chatLog.messages) { _ in
						if let msg = self.model.chatLog.messages.last {
							if msg.role == .ai {
//								let speech = msg.message
//								print("# speech=\(speech)")

								self.response = msg.message
							}
						}
					}
					.onChange(of: self.model.isGenerating) { _ in
						if self.model.isGenerating == false {
							if self.response.count > 0 {
//								speechSynthesizer.speak(self.response)
								self.message = ""
							}
						}
					}
				}
			}
		}
		.padding()
		.onAppear {
			self.speechRecognizer.requestAccess {
			}
			self.speechRecognizer.onResult = { result in
				self.message = result.bestTranscription.formattedString
				print("recognizeResult: \(result)")
//				let confidence = result.bestTranscription.segments[0].confidence
//				let isFinal = confidence > 0.0 ? true : false
//				if isFinal {
//					print("recognize command")
//					self.speechRecognizer.newLine()
//					self.model.addChatMessage(self.message, instruction: instruction, example: chatExample, userMessagePrefix: "User:", aiMessagePrefix: "Hoa:")
//					self.message = ""
//				}
			}

			Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
				print("voice recognition start")
				self.speechRecognizer.startRecognition()
			}
			self.responseTimer = Timer.scheduledTimer(withTimeInterval: responseInterval, repeats: true) { _ in
				guard !self.message.isEmpty else { return }
				if self.message == self.lastMessage {
					print("recognize command")
					self.message = ""
					self.speechRecognizer.newLine()
					self.model.addChatMessage(self.lastMessage, instruction: instruction, example: chatExample, userMessagePrefix: "User:", aiMessagePrefix: "Hoa:")
					self.lastMessage = "---"
				}
				else {
					self.lastMessage = self.message
				}
			}
		}
	}
}

#Preview {
	ContentView()
}

class SpeechSynthesizer {
	private let synthesizer = AVSpeechSynthesizer()

	func speak(_ text: String) {
		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
		synthesizer.speak(utterance)
	}
}

class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
#if os(visionOS)
	private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
#else
	private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
#endif
	private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	private var recognitionTask: SFSpeechRecognitionTask?
	private let audioEngine = AVAudioEngine()
	var isBufferReady = false

	var onResult: ((SFSpeechRecognitionResult) -> Void)?

	override init() {
		super.init()
		speechRecognizer.delegate = self
	}

	func requestAccess(completion:@escaping ()->Void){
		var authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
		switch authStatus {
			case .authorized:
				return
			case .notDetermined:
				AVCaptureDevice.requestAccess(for: .audio) { granted in	// need NSCameraUsageNSCameraUsage as well as NSMicrophoneUsageDescription in info.plist to requestAccess
					if granted {
						SFSpeechRecognizer.requestAuthorization { status in
							completion()
						}
					}
				}
				return
			case .denied:
				return
			case .restricted:
				return
		}
	}

	func startRecognition() {
		if audioEngine.isRunning {
			stopRecognition()
		} else {
			do {
				try startRecording()
			} catch {
				print("Failed to start recording")
			}
		}
	}

	func stopRecognition() {
		if audioEngine.isRunning {
			recognitionTask?.finish()
			audioEngine.stop()
			recognitionRequest?.endAudio()
		}
	}
	
	func newLine() {
		do {
			try stopRecording()
			try startRecording()
		} catch {
			print("Failed to start recording")
		}
	}
	
	private func startRecording() throws {
		recognitionTask?.cancel()
		recognitionTask = nil
		
		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

		let inputNode = audioEngine.inputNode

		guard let recognitionRequest = recognitionRequest else {
			fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
		}

		recognitionRequest.shouldReportPartialResults = true

		recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
			if let result = result {
				DispatchQueue.main.async {
					self.onResult?(result)
				}
			}
		}

		if isBufferReady==false {
			isBufferReady = true
			let recordingFormat = inputNode.outputFormat(forBus: 0)
			inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
				self.recognitionRequest?.append(buffer)
			}
		}

		audioEngine.prepare()
		try audioEngine.start()
	}
	
	private func stopRecording() throws {
		audioEngine.stop()
		recognitionRequest?.endAudio()
		recognitionTask?.finish()
		recognitionTask = nil
	}
	/// マイク・音声認識使用許可確認
	/// - Returns: True:許諾済 False:許諾拒否
	func authorization()->Bool{
		if(AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == .authorized &&
			SFSpeechRecognizer.authorizationStatus() == .authorized){
			return true
		} else {
			return false
		}
	}

}
