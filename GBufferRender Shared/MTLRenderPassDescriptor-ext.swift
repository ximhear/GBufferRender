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
    
    func setColorAttachment(position: Int, texture: MTLTexture) {
        let a: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
        a.texture = texture
        a.loadAction = .clear
        a.storeAction = .store
        a.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
    }
}
