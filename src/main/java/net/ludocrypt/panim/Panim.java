package net.ludocrypt.panim;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.annotation.Nullable;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.lwjgl.glfw.GLFW;
import org.quiltmc.loader.api.ModContainer;
import org.quiltmc.qsl.base.api.entrypoint.client.ClientModInitializer;
import org.quiltmc.qsl.lifecycle.api.client.event.ClientTickEvents;

import com.mojang.blaze3d.framebuffer.Framebuffer;
import com.mojang.blaze3d.framebuffer.SimpleFramebuffer;
import com.mojang.blaze3d.platform.InputUtil;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.texture.NativeImage;

import net.fabricmc.fabric.impl.client.keybinding.KeyBindingRegistryImpl;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBind;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Util;
import net.minecraft.util.math.Vec3d;

public class Panim implements ClientModInitializer {

	public static KeyBind keyBinding;

	public static Vec3d oririn = Vec3d.ZERO;

	public static SimpleFramebuffer[] maps = new SimpleFramebuffer[6];

	public static final Logger LOGGER = LogManager.getLogger("Panim");

	@Override
	public void onInitializeClient(ModContainer mod) {
		keyBinding = KeyBindingRegistryImpl.registerKeyBinding(new KeyBind("panim.boot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, "panim.cata"));

		ClientTickEvents.END.register(client -> {
			if (keyBinding.wasPressed()) {
				oririn = client.gameRenderer.getCamera().getPos();

				SimpleFramebuffer[] buffers = takePanorama(client, 2048, 2048);
				for (int i = 0; i < 6; i++) {
					if (maps[i] != null) {
						maps[i].delete();
					}
					maps[i] = buffers[i];
				}
			}
		});
	}

	public static SimpleFramebuffer[] takePanorama(MinecraftClient client, int width, int height) {
		int i = client.getWindow().getFramebufferWidth();
		int j = client.getWindow().getFramebufferHeight();
		float f = client.player.getPitch();
		float g = client.player.getYaw();
		float h = client.player.prevPitch;
		float k = client.player.prevYaw;
		client.gameRenderer.setBlockOutlineEnabled(false);

		SimpleFramebuffer[] framebuffers = new SimpleFramebuffer[6];

		try {
			client.worldRenderer.reloadTransparencyShader();
			client.getWindow().setFramebufferWidth(width);
			client.getWindow().setFramebufferHeight(height);

			for (int l = 0; l < 6; ++l) {
				switch (l) {
				case 0:
					client.player.setYaw(0);
					client.player.setPitch(0.0F);
					break;
				case 1:
					client.player.setYaw((90.0F) % 360.0F);
					client.player.setPitch(0.0F);
					break;
				case 2:
					client.player.setYaw((180.0F) % 360.0F);
					client.player.setPitch(0.0F);
					break;
				case 3:
					client.player.setYaw((-90.0F) % 360.0F);
					client.player.setPitch(0.0F);
					break;
				case 4:
					client.player.setYaw(0);
					client.player.setPitch(-90.0F);
					break;
				case 5:
				default:
					client.player.setYaw(0);
					client.player.setPitch(90.0F);
				}

				client.player.prevYaw = client.player.getYaw();
				client.player.prevPitch = client.player.getPitch();
				SimpleFramebuffer framebuffer = new SimpleFramebuffer(width, height, true, MinecraftClient.IS_SYSTEM_MAC);
				framebuffer.beginWrite(true);

				client.gameRenderer.setRenderingPanorama(true);
				client.gameRenderer.renderWorld(1.0F, 0L, new MatrixStack());
				client.gameRenderer.setRenderingPanorama(false);

				try {
					Thread.sleep(10L);
				} catch (InterruptedException var17) {
				}

				saveScreenshotInner("panorama_" + l + ".png", framebuffer);
				framebuffers[l] = framebuffer;
			}

			return framebuffers;
		} catch (Exception var18) {
			LOGGER.error("Couldn't save image", var18);
		} finally {
			client.player.setPitch(f);
			client.player.setYaw(g);
			client.player.prevPitch = h;
			client.player.prevYaw = k;
			client.gameRenderer.setBlockOutlineEnabled(true);
			client.getWindow().setFramebufferWidth(i);
			client.getWindow().setFramebufferHeight(j);
			client.worldRenderer.reloadTransparencyShader();
			client.getFramebuffer().beginWrite(true);
		}

		return framebuffers;
	}

	private static void saveScreenshotInner(@Nullable String fileName, Framebuffer framebuffer) {
		NativeImage nativeImage = depthImage(framebuffer);
		File file = new File(new File(MinecraftClient.getInstance().runDirectory, "screenshots"), "panim");
		file.mkdir();
		File file2;
		if (fileName == null) {
			file2 = getScreenshotFilename(file);
		} else {
			file2 = new File(file, fileName);
		}

		Util.getIoWorkerExecutor().execute(() -> {
			try {
				nativeImage.writeFile(file2);
			} catch (Exception var7) {
				LOGGER.warn("Couldn't save screenshot", var7);
			} finally {
				nativeImage.close();
			}
		});
	}

	private static File getScreenshotFilename(File directory) {
		String string = new SimpleDateFormat("yyyy-MM-dd_HH.mm.ss").format(new Date());
		int i = 1;

		while (true) {
			File file = new File(directory, string + (i == 1 ? "" : "_" + i) + ".png");
			if (!file.exists()) {
				return file;
			}

			++i;
		}
	}

	public static NativeImage depthImage(Framebuffer framebuffer) {
		int i = framebuffer.textureWidth;
		int j = framebuffer.textureHeight;
		NativeImage nativeImage = new NativeImage(NativeImage.Format.ABGR, i, j, false);
		RenderSystem.bindTexture(framebuffer.getColorAttachment());
		nativeImage.loadFromTextureImage(0, true);
		nativeImage.mirrorVertically();
		return nativeImage;
	}

}
