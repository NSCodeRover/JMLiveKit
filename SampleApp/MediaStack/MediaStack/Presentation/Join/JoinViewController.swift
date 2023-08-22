//
//  JoinViewController.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 27/02/23.
//

import UIKit

import UIKit
import WebRTC


class JoinViewController: UIViewController {
    @IBOutlet weak var txtRoomId: UITextField!
    @IBOutlet weak var txtPin: UITextField!
    @IBOutlet weak var txtName: UITextField!
    private var viewModel = MeetingRoomViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = false
        
    #if PROD
        //https://jiomeetpro.jio.com/shortener?meetingId=2498110346&pwd=VX9Hf
        self.txtRoomId.text = "2498110346"
        self.txtPin.text = "VX9Hf"
    #elseif RC
        //https://rc.jiomeet.jio.com/shortener?meetingId=6918050138&pwd=MPm1d
        self.txtRoomId.text = "6918050138"
        self.txtPin.text = "MPm1d"
    #else
        //https://prestage.jiomeet.com/join?meetingId=7330377010&pwd=Z381t
        self.txtRoomId.text = "7330377010"
        self.txtPin.text = "Z381t"
    #endif
        self.txtName.text = "Harsh Debug"
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
        
        self.viewModel.handleEvent(event: .join(roomId: self.txtRoomId.text ?? "", pin: self.txtPin.text ?? "", name: self.txtName.text ?? ""))
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
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        blurEffectView.contentView.addSubview(activityIndicator)
        activityIndicator.center = blurEffectView.contentView.center
        activityIndicator.startAnimating()
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
