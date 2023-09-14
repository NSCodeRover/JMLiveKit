//
//  JoinViewController.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 27/02/23.
//

import UIKit

import UIKit
import WebRTC

var globalServerPoint: AppEnvironment = .Prod
enum AppEnvironment: String{
    case Prod
    case RC
    case Prestage
}


class JoinViewController: UIViewController {
    @IBOutlet weak var txtRoomId: UITextField!
    @IBOutlet weak var txtPin: UITextField!
    @IBOutlet weak var txtName: UITextField!
    @IBOutlet weak var switchHD: UISwitch!
    @IBOutlet weak var switchEnv: UIButton!
    private var viewModel = MeetingRoomViewModel()
    
    var envDropdown: UIAlertController!

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        self.navigationController?.isNavigationBarHidden = false
        
        configureEnv()
        addViewModelListener()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    @IBAction func joinAction(_ sender: Any) {
        self.view.showBlurLoader()
        
        viewModel.joinChannelLoader = {
            self.view.removeBlurLoader()
        }
        
        self.viewModel.handleEvent(event: .join(roomId: self.txtRoomId.text ?? "", pin: self.txtPin.text ?? "", name: self.txtName.text ?? "", isHd: switchHD.isOn))
    }
    
    @IBAction func switchEnvAction(_ sender: Any) {
        if let popoverController = envDropdown.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(envDropdown, animated: true, completion: nil)
    }
    
    func configureEnv(){
        
        self.txtRoomId.text = "2498110346"
        self.txtPin.text = "VX9Hf"
        self.switchEnv.setTitle(globalServerPoint.rawValue, for: .normal)
        
        self.txtName.text = "Harsh Debug"
        
        let env: [AppEnvironment] = [.Prod,.RC,.Prestage]
        envDropdown = UIAlertController(title: "Environment Switch", message: nil, preferredStyle: .actionSheet)
        
        for server in env{
            let server = UIAlertAction(title: server.rawValue, style: .default) { _ in
                self.switchEnv(server)
            }
            envDropdown.addAction(server)
        }
       
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        envDropdown.addAction(cancel)
    }
    
    func switchEnv(_ server: AppEnvironment){
        globalServerPoint = server
        self.switchEnv.setTitle(server.rawValue, for: .normal)
        
        switch server{
        case .Prod:
            self.txtRoomId.text = "2498110346"
            self.txtPin.text = "VX9Hf"
        case .RC:
            self.txtRoomId.text = "6918050138"
            self.txtPin.text = "MPm1d"
        case .Prestage:
            self.txtRoomId.text = "7330377010"
            self.txtPin.text = "Z381t"
        }
    }
}

// MARK: - Private Methods
extension JoinViewController {
    func addViewModelListener() {
        self.viewModel.pushToMeetingRoom = { (result,message) in
            DispatchQueue.main.async {
                self.view.removeBlurLoader()
                if result{
                    if let viewController = self.storyboard?.instantiateViewController(withIdentifier: "MeetingRoomViewController") as? MeetingRoomViewController {
                        viewController.viewModel = self.viewModel
                        self.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
                else{
                    self.showToast(message)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate Methods
extension JoinViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true;
    }
}


extension UIView {
    func showBlurLoader() {
        let blurLoader = BlurLoader(frame: frame)
        self.addSubview(blurLoader)
    }

    func removeBlurLoader() {
        if let blurLoader = subviews.first(where: { $0 is BlurLoader }) {
            blurLoader.removeFromSuperview()
        }
    }
}


class BlurLoader: UIView {

    var blurEffectView: UIVisualEffectView?

    override init(frame: CGRect) {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.blurEffectView = blurEffectView
        super.init(frame: frame)
        addSubview(blurEffectView)
        addLoader()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addLoader() {
        guard let blurEffectView = blurEffectView else { return }
        if #available(iOS 13.0, *) {
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            blurEffectView.contentView.addSubview(activityIndicator)
            activityIndicator.center = blurEffectView.contentView.center
            activityIndicator.startAnimating()
        } else {
            let activityIndicator = UIActivityIndicatorView()
            activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            blurEffectView.contentView.addSubview(activityIndicator)
            activityIndicator.center = blurEffectView.contentView.center
            activityIndicator.startAnimating()
        }
    }
}

extension UIViewController {
    func showToast(_ message: String) {
        let controller: UIViewController = self
        let toastContainer = UIView(frame: CGRect())
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastContainer.alpha = 0.0
        toastContainer.layer.cornerRadius = 25;
        toastContainer.clipsToBounds  =  true

        let toastLabel = UILabel(frame: CGRect())
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font.withSize(12.0)
        toastLabel.text = message
        toastLabel.clipsToBounds  =  true
        toastLabel.numberOfLines = 0

        toastContainer.addSubview(toastLabel)
        controller.view.addSubview(toastContainer)

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false

        let a1 = NSLayoutConstraint(item: toastLabel, attribute: .leading, relatedBy: .equal, toItem: toastContainer, attribute: .leading, multiplier: 1, constant: 15)
        let a2 = NSLayoutConstraint(item: toastLabel, attribute: .trailing, relatedBy: .equal, toItem: toastContainer, attribute: .trailing, multiplier: 1, constant: -15)
        let a3 = NSLayoutConstraint(item: toastLabel, attribute: .bottom, relatedBy: .equal, toItem: toastContainer, attribute: .bottom, multiplier: 1, constant: -15)
        let a4 = NSLayoutConstraint(item: toastLabel, attribute: .top, relatedBy: .equal, toItem: toastContainer, attribute: .top, multiplier: 1, constant: 15)
        toastContainer.addConstraints([a1, a2, a3, a4])

        let c1 = NSLayoutConstraint(item: toastContainer, attribute: .leading, relatedBy: .equal, toItem: controller.view, attribute: .leading, multiplier: 1, constant: 65)
        let c2 = NSLayoutConstraint(item: toastContainer, attribute: .trailing, relatedBy: .equal, toItem: controller.view, attribute: .trailing, multiplier: 1, constant: -65)
        let c3 = NSLayoutConstraint(item: toastContainer, attribute: .bottom, relatedBy: .equal, toItem: controller.view, attribute: .bottom, multiplier: 1, constant: -75)
        controller.view.addConstraints([c1, c2, c3])

        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            toastContainer.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 1.5, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }, completion: {_ in
                toastContainer.removeFromSuperview()
            })
        })
    }
}
