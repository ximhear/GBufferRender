//
//  Renderer.swift
//  GBufferRender Shared
//
//  Created by gzonelee on 2022/03/15.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 6

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    var models: [Model] = []
    var lights: [Light] = []
    var lightsBuffer: MTLBuffer!
    
    var shadowTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    var shadowPipelineState: MTLRenderPipelineState!
    
    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var positionTexture: MTLTexture!
    var depthTexture: MTLTexture!
   
    var gBufferPipelineState: MTLRenderPipelineState!
    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!
    
    var compositionPipelinestate: MTLRenderPipelineState!
    var quadVerticesBuffer: MTLBuffer!
    var quadTexCoordsBuffer: MTLBuffer!
    
    let quadVertices: [Float] = [
        -1.0, 1.0,
         1.0, -1.0,
         -1, -1,
         -1, 1,
         1, 1,
         1, -1
    ]
    
    let quadTexCoords: [Float] = [
        0, 0,
        1, 1,
        0, 1,
        0, 0,
        1, 0,
        1, 1
    ]
    
    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        metalKitView.framebufferOnly = false
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state
        
        do {
            var mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
            var model = Model(mesh: mesh)
            model.rotationY = Float.pi / 4.0
            model.scale = [1, 3, 1]
            model.position = [1, 1.5, -1]
            model.color = [1, 0.8, 0.1, 1]
            models.append(model)
            
            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
            model = Model(mesh: mesh)
            model.rotationY = Float.pi / 4.0
            model.scale = [1, 1, 1]
            model.position = [-1, 1.5, 1.5]
            model.color = [0.85, 0.25, 0.75, 1]
            models.append(model)
            
            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
            model = Model(mesh: mesh)
            model.rotationY = 0
            model.scale = [10, 1, 10]
            model.position = [0, -0.5, 2]
            model.color = [1, 1, 1, 1]
            models.append(model)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        do {
            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }
        
        super.init()
        
        let sunlight = Light(type: .sunlight, color: [1, 1, 1], position: [1, 1, -1], target: [0, 0, 0], attenuation: [1, 1, 1], coneAngle: 0, coneDirection: [0, 0, 0], coneAttenuation: 1)
        self.lights.append(sunlight)
        
        let pointlight = Light(type: .pointlight, color: [1, 0, 0], position: [0, 0.1, 0], target: [0, 0, 0], attenuation: [1, 3, 4], coneAngle: 0, coneDirection: [0, 0, 0], coneAttenuation: 1)
//        self.lights.append(pointlight)
        createPointLights(count: 50, min: [-5, 0, -5], max: [5, 0.05, 5])
        lightsBuffer = device.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
        
        buildShadowTexture(size: metalKitView.drawableSize)
        buildShadowPipelineState(mtlVertexDescriptor: mtlVertexDescriptor)
        buildGBufferPipelineState(mtlVertexDescriptor: mtlVertexDescriptor)
        buildCompositionPipelineState(metalView: metalKitView)
        
        quadVerticesBuffer = device.makeBuffer(bytes: quadVertices, length: MemoryLayout<Float>.size * quadVertices.count, options: [])
        quadVerticesBuffer.label = "Quad vertices"
        quadTexCoordsBuffer = device.makeBuffer(bytes: quadTexCoords, length: MemoryLayout<Float>.size * quadTexCoords.count, options: [])
        quadTexCoordsBuffer.label = "Quad texCoords"
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].bufferIndex = BufferIndex.meshNormal.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshNormal.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshNormal.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshNormal.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func buildShadowPipelineState(mtlVertexDescriptor: MTLVertexDescriptor) {
        let d = MTLRenderPipelineDescriptor()
        let library = device.makeDefaultLibrary()
        d.vertexFunction = library?.makeFunction(name: "vertex_depth")
        d.fragmentFunction = nil
        d.colorAttachments[0].pixelFormat = .invalid
        d.vertexDescriptor = mtlVertexDescriptor
        d.depthAttachmentPixelFormat = .depth32Float
        do {
            shadowPipelineState = try device.makeRenderPipelineState(descriptor: d)
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(1, 1, 1),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals:false,
                                     allocator: metalAllocator)
        
//        mdlMesh.addAttribute(withName: MDLVertexAttributeNormal, format: .float3)
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        attributes[VertexAttribute.normal.rawValue].name = MDLVertexAttributeNormal
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
        
    }
    
    func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String) -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
        
        d.usage = [.shaderRead, .renderTarget]
        d.storageMode = .private
        guard let texture = device.makeTexture(descriptor: d) else {
            GZLogFunc()
            fatalError()
        }
        texture.label = "\(label) texture"
        return texture
    }
    
    func buildGBufferTexture(size: CGSize) {
        albedoTexture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "Albedo texxture")
        normalTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Normal texxture")
        positionTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Position texxture")
        depthTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Depth texxture")
    }
    
    func buildShadowTexture(size: CGSize) {
        shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)
    }
    
    
    func buildGBufferRenderPassDescriptor(size: CGSize) {
        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        buildGBufferTexture(size: size)
        let textures: [MTLTexture] = [
            albedoTexture,
            normalTexture,
            positionTexture
        ]
        for (position, texture) in textures.enumerated() {
            gBufferRenderPassDescriptor.setColorAttachment(position: position, texture: texture)
        }
        gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
    }
    
    func buildGBufferPipelineState(mtlVertexDescriptor: MTLVertexDescriptor) {
        let d = MTLRenderPipelineDescriptor()
        d.colorAttachments[0].pixelFormat = .bgra8Unorm
        d.colorAttachments[1].pixelFormat = .rgba16Float
        d.colorAttachments[2].pixelFormat = .rgba16Float
        d.depthAttachmentPixelFormat = .depth32Float
        d.label = "BGuffer state"
        
        let library = device.makeDefaultLibrary()
        d.vertexFunction = library?.makeFunction(name: "vertexShader")
        d.fragmentFunction = library?.makeFunction(name: "gBufferFragment")
        d.vertexDescriptor = mtlVertexDescriptor
        do {
            gBufferPipelineState = try device.makeRenderPipelineState(descriptor: d)
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func buildCompositionPipelineState(metalView: MTKView) {
        let d = MTLRenderPipelineDescriptor()
        d.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        d.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        d.stencilAttachmentPixelFormat = metalView.depthStencilPixelFormat
        d.label = "Composition state"
        let library = device.makeDefaultLibrary()
        d.vertexFunction = library?.makeFunction(name: "compositionVert")
        d.fragmentFunction = library?.makeFunction(name: "compositionFrag")
        do {
            compositionPipelinestate = try device.makeRenderPipelineState(descriptor: d)
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = projectionMatrix
        
        let viewMatrix = matrix4x4_translation(0.0, -1.5, 8.0)
        uniforms[0].viewMatrix = viewMatrix * matrix4x4_rotation(radians: -Float.pi / 6.0, axis: [1, 0, 0])
        rotation += 0.01
        uniforms[0].shadowMatrix = shadowMatrix
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        guard let drawable = view.currentDrawable else {
            return
        }
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor) else {
                return
            }
            self.updateDynamicBufferState()
            
            renderShadowPass(renderEncoder: shadowEncoder)
            
            guard let gBufferEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor) else {
                return
            }
            renderGBufferPass(renderEncoder: gBufferEncoder)
            
            self.updateDynamicBufferState()
            self.updateGameState()
            
//            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
//                return
//            }
//
//            blitEncoder.pushDebugGroup("Blit")
//            blitEncoder.label = "Blit encoder"
//            let origin = MTLOrigin(x: 0, y: 0, z: 0)
//            let size = MTLSize(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height), depth: 1)
//            blitEncoder.copy(from: albedoTexture, sourceSlice: 0,
//                             sourceLevel: 0,
//                             sourceOrigin: origin,
//                             sourceSize: size,
//                             to: drawable.texture,
//                             destinationSlice: 0,
//                             destinationLevel: 0,
//                             destinationOrigin: origin
//            )
//            blitEncoder.endEncoding()
//            blitEncoder.popDebugGroup()
            
            if let d = view.currentRenderPassDescriptor, let compositionEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: d) {
                renderCompositionPass(renderEncoder: compositionEncoder)
            }
//            let renderPassDescriptor = view.currentRenderPassDescriptor
//
//            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
//
//                /// Final pass rendering code here
//                renderEncoder.label = "Primary Render Encoder"
//
//                renderEncoder.pushDebugGroup("Draw Box")
//
//                renderEncoder.setCullMode(.back)
//
//                renderEncoder.setFrontFacing(.clockwise)
//
//                renderEncoder.setRenderPipelineState(pipelineState)
//
//                renderEncoder.setDepthStencilState(depthState)
//
//                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//                var lightCount = lights.count
//                renderEncoder.setFragmentBytes(&lightCount, length: MemoryLayout<Int>.stride, index: BufferIndex.lightCount.rawValue)
//                renderEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lightCount, index: BufferIndex.lights.rawValue)
//                renderEncoder.setFragmentTexture(shadowTexture, index: TextureIndex.depth.rawValue)
//
//                for (index, x) in models.enumerated() {
//                    if index == models.count - 1 {
//                        x.render(renderEncoder: renderEncoder) { m in
//                        }
//                    }
//                    else {
//                        x.render(renderEncoder: renderEncoder) { m in
//                            m.rotationY = rotation * Float(index + 1)
//                        }
//                    }
//                }
//
//                renderEncoder.popDebugGroup()
//
//                renderEncoder.endEncoding()
//
//                if let drawable = view.currentDrawable {
//                    commandBuffer.present(drawable)
//                }
//            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    var shadowMatrix: float4x4 = .identity()
    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setFrontFacing(.clockwise)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
        
        uniforms[0].projectionMatrix = .init(orthoLeft: -8, right: 8, bottom: -8, top: 8, near: 0.1, far: 16)
        let pos: SIMD3<Float> = lights[0].position
        let center: SIMD3<Float> = lights[0].target
       
        let lookAt = float4x4.init(eye: pos, center: center, up: [0, 1, 0])
        uniforms[0].viewMatrix = lookAt
        uniforms[0].shadowMatrix = uniforms[0].projectionMatrix * uniforms[0].viewMatrix
        shadowMatrix = uniforms[0].shadowMatrix;
        renderEncoder.setRenderPipelineState(shadowPipelineState)
                
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
        
        for (index, x) in models.enumerated() {
            if index == models.count - 1 {
                x.render(renderEncoder: renderEncoder) { m in
                }
            }
            else {
                x.render(renderEncoder: renderEncoder) { m in
                    m.rotationY = rotation * Float(index + 1)
                }
            }
        }
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    func renderGBufferPass(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("GBuffer pass")
        renderEncoder.label = "GBuffer encoder"
        
        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        self.updateDynamicBufferState()
        self.updateGameState()
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.clockwise)
        
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
        var lightCount = lights.count
        renderEncoder.setFragmentBytes(&lightCount, length: MemoryLayout<Int>.stride, index: BufferIndex.lightCount.rawValue)
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: BufferIndex.lights.rawValue)
        renderEncoder.setFragmentTexture(shadowTexture, index: TextureIndex.depth.rawValue)
        
        for (index, x) in models.enumerated() {
            if index == models.count - 1 {
                x.render(renderEncoder: renderEncoder) { m in
                }
            }
            else {
                x.render(renderEncoder: renderEncoder) { m in
                    m.rotationY = rotation * Float(index + 1)
                }
            }
        }
        
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Composition pass")
        renderEncoder.label = "Composition encoder"
        renderEncoder.setRenderPipelineState(compositionPipelinestate)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(quadTexCoordsBuffer, offset: 0, index: 1)
        
        renderEncoder.setFragmentTexture(albedoTexture, index: 0)
        renderEncoder.setFragmentTexture(normalTexture, index: 1)
        renderEncoder.setFragmentTexture(positionTexture, index: 2)
        var lightCount = lights.count
        renderEncoder.setFragmentBytes(&lightCount, length: MemoryLayout<Int>.stride, index: 0)
//        renderEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lights.count, index: 1)
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_left_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
        buildShadowTexture(size: size)
        buildGBufferRenderPassDescriptor(size: size)
    }
    
    func createPointLights(count: Int, min: SIMD3<Float>, max: SIMD3<Float>) {
        let colors: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(1, 1, 0),
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 1, 1),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(0, 1, 1),
            SIMD3<Float>(1, 0, 1) ]
        let newMin: SIMD3<Float> = [min.x*100, min.y*100, min.z*100]
        let newMax: SIMD3<Float> = [max.x*100, max.y*100, max.z*100]
        for _ in 0..<count {
            var light = buildDefaultLight()
            light.type = .pointlight
            let x = Float(random(range: Int(newMin.x)...Int(newMax.x))) * 0.01
            let y = Float(random(range: Int(newMin.y)...Int(newMax.y))) * 0.01
            let z = Float(random(range: Int(newMin.z)...Int(newMax.z))) * 0.01
            light.position = [x, y, z]
            light.color = colors[random(range: 0...colors.count)]
            light.attenuation = [2, 5, 9]
            lights.append(light)
        }
    }
    
    func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.target = [0, 0, 0]
        light.attenuation = [1, 0, 0]
        light.type = .sunlight
        return light
    }
    
    func random(range: CountableClosedRange<Int>) -> Int {
        var offset = 0
        if range.lowerBound < 0 {
            offset = abs(range.lowerBound)
        }
        let min = UInt32(range.lowerBound + offset)
        let max = UInt32(range.upperBound + offset)
        return Int(min + arc4random_uniform(max-min)) - offset
    }
}

