//
//  UIView+Extension.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 28/02/23.
//

import Foundation
import UIKit

extension UIView {
    static var nib: UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
}

extension UIView {
  func makeDraggable() {
      let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
      self.addGestureRecognizer(panGesture)
  }
  
  @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
      guard gesture.view != nil else { return }
      
      let translation = gesture.translation(in: gesture.view?.superview)
      
      var newX = gesture.view!.center.x + translation.x
      var newY = gesture.view!.center.y + translation.y
      
      let halfWidth = gesture.view!.bounds.width / 2.0
      let halfHeight = gesture.view!.bounds.height / 2.0
      
      // Limit the movement to stay within the bounds of the screen
      newX = max(halfWidth, newX)
      newX = min(UIScreen.main.bounds.width - halfWidth, newX)
      newY = max(halfHeight, newY)
      newY = min(UIScreen.main.bounds.height - halfHeight, newY)
      
      gesture.view?.center = CGPoint(x: newX, y: newY)
      gesture.setTranslation(CGPoint.zero, in: gesture.view?.superview)
  }
}
