//
//  MTLRenderPassDescriptor-ext.swift
//  GBufferRender
//
//  Created by gzonelee on 2022/03/16.
//

import Foundation
import MetalKit

extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1.0
    }
}
