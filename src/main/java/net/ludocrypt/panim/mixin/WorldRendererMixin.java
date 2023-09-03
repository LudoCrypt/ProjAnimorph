package net.ludocrypt.panim.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.At.Shift;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import com.mojang.blaze3d.systems.RenderSystem;

import net.ludocrypt.panim.Panim;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.Camera;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.ShaderProgram;
import net.minecraft.client.render.WorldRenderer;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Matrix4f;

@Mixin(WorldRenderer.class)
public class WorldRendererMixin {

	@Inject(method = "Lnet/minecraft/client/render/WorldRenderer;renderLayer(Lnet/minecraft/client/render/RenderLayer;Lnet/minecraft/client/util/math/MatrixStack;DDDLnet/minecraft/util/math/Matrix4f;)V", at = @At(value = "INVOKE", target = "Lcom/mojang/blaze3d/systems/RenderSystem;getShader()Lnet/minecraft/client/render/ShaderProgram;", shift = Shift.AFTER))
	private void renderLayer(RenderLayer renderLayer, MatrixStack matrices, double sortX, double sortY, double sortZ, Matrix4f projectionMatrix, CallbackInfo ci) {
		ShaderProgram shaderProgram = RenderSystem.getShader();
		MinecraftClient client = MinecraftClient.getInstance();
		Camera camera = client.gameRenderer.getCamera();

		RenderSystem.setShaderTexture(4, new Identifier("textures/animorph.png"));
		float tickDelta = RenderSystem.getShaderGameTime() * 24000.0F - (client.world.getTime() % 24000.0F);

		for (int i = 0; i < 6; i++) {
			if (Panim.maps[i] != null) {
				RenderSystem.setShaderTexture(5 + i, Panim.maps[i].getDepthAttachment());
			}
		}

		if (shaderProgram.getUniform("ScreenSize") != null) {
			shaderProgram.getUniform("ScreenSize").setVec2(client.getFramebuffer().viewportWidth, client.getFramebuffer().viewportHeight);
		}

		if (shaderProgram.getUniform("Origin") != null) {
			shaderProgram.getUniform("Origin").setVec3((float) Panim.oririn.x, (float) Panim.oririn.y, (float) Panim.oririn.z);
		}

		if (shaderProgram.getUniform("CameraPos") != null) {
			shaderProgram.getUniform("CameraPos").setVec3((float) camera.getPos().x, (float) camera.getPos().y, (float) camera.getPos().z);
		}

		if (shaderProgram.getUniform("FarFar") != null) {
			shaderProgram.getUniform("FarFar").setFloat(client.gameRenderer.getFarDepth());
		}

		if (shaderProgram.getUniform("renderingPanorama") != null) {
			shaderProgram.getUniform("renderingPanorama").setFloat(client.gameRenderer.isRenderingPanorama() ? 1 : 0);
		}

		MatrixStack matrixStack = new MatrixStack();

		((GameRendererAccessor) client.gameRenderer).callBobViewWhenHurt(matrixStack, tickDelta);
		if (client.options.getBobView().get()) {
			((GameRendererAccessor) client.gameRenderer).callBobView(matrixStack, tickDelta);
		}

		double fov = ((GameRendererAccessor) client.gameRenderer).callGetFov(camera, tickDelta, true);

		MatrixStack basicStack = new MatrixStack();
		basicStack.multiplyMatrix(client.gameRenderer.getBasicProjectionMatrix(fov));

		if (shaderProgram.getUniform("BasicMat") != null) {
			shaderProgram.getUniform("BasicMat").setMat4x4(basicStack.peek().getPosition());
		}

		if (shaderProgram.getUniform("BobMat") != null) {
			shaderProgram.getUniform("BobMat").setMat4x4(matrixStack.peek().getPosition());
		}

	}

}
