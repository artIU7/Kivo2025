//
//  MessageViewController.swift
//  kivo
//
//  Created by Артем Стратиенко on 16.08.2025.
//

import UIKit

class MessageSheetViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Отправить сообщение"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private let textField: UITextField = {
        let field = UITextField()
        field.placeholder = "Введите ваше сообщение..."
        field.borderStyle = .roundedRect
        field.autocorrectionType = .no
        field.returnKeyType = .done
        return field
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Отправить", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        return stack
    }()
    
    // MARK: - Properties
    
    var onSend: ((String) -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        configureSheet()
        setupKeyboardHandling()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(textField)
        stackView.addArrangedSubview(sendButton)
        
        view.addSubview(stackView)
        
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        textField.delegate = self
    }
    
    private func setupConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            sendButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureSheet() {
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
        }
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func sendButtonTapped() {
        guard let text = textField.text, !text.isEmpty else {
            showAlert(message: "Пожалуйста, введите сообщение")
            return
        }
        
        onSend?(text)
        dismiss(animated: true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if #available(iOS 15.0, *),
           let sheet = sheetPresentationController,
           sheet.selectedDetentIdentifier == .medium,
           let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            
            let keyboardHeight = keyboardFrame.height
            let newHeight = view.bounds.height - keyboardHeight - 40
        }
    }
    
    @objc private func keyboardWillHide() {
        if #available(iOS 15.0, *) {
            sheetPresentationController?.animateChanges {
                sheetPresentationController?.detents = [.medium(), .large()]
                sheetPresentationController?.selectedDetentIdentifier = .medium
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension MessageSheetViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Usage Example

extension UIViewController {
    func presentMessageSheet(onSend: @escaping (String) -> Void) {
        let sheetVC = MessageSheetViewController()
        sheetVC.onSend = onSend
        present(sheetVC, animated: true)
    }
}
