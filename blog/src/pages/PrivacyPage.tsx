import React from 'react';
import { LegalPageLayout } from '../components/LegalPageLayout';

export const PrivacyPage: React.FC = () => {
  return (
    <LegalPageLayout title="Aviso de Privacidad">
      <div className="prose prose-lg max-w-none">
        <div className="mb-8 pb-6 border-b" style={{ borderColor: '#E8F5F4' }}>
          <p className="text-sm font-semibold mb-1" style={{ color: '#4DB3A8' }}>
            Sitio: https://narra.mx
          </p>
          <p className="text-sm font-semibold mb-1" style={{ color: '#4DB3A8' }}>
            Titular del tratamiento: Narra
          </p>
          <p className="text-sm" style={{ color: '#6B7280' }}>
            Última actualización: 11 de noviembre de 2025
          </p>
        </div>

        <p style={{ color: '#4B5563' }}>
          En cumplimiento de la legislación vigente en materia de protección de datos personales, incluyendo de forma enunciativa pero no limitativa:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>la <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares (México)</strong> y su Reglamento,</li>
          <li>principios y derechos reconocidos en <strong>Latinoamérica</strong>,</li>
          <li>el <strong>Reglamento General de Protección de Datos (GDPR)</strong> aplicable a usuarios ubicados en la Unión Europea,</li>
          <li>y estándares de privacidad de <strong>EE. UU.</strong> cuando apliquen,</li>
        </ul>
        <p style={{ color: '#4B5563' }}>
          <strong>Narra</strong> pone a su disposición el presente <strong>Aviso de Privacidad</strong> para explicar qué datos recabamos, para qué los usamos, con quién los compartimos y qué derechos tiene usted como titular.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>1. Identidad y contacto del responsable</h2>
        <p style={{ color: '#4B5563' }}>
          <strong>Narra</strong> es la responsable del tratamiento de sus datos personales recabados a través del sitio web <strong>https://narra.mx</strong> y de los servicios digitales asociados (en adelante, el "Sitio" o la "Plataforma").
        </p>
        <div className="p-6 rounded-2xl my-6" style={{ background: '#E8F5F4' }}>
          <p className="font-bold mb-2" style={{ color: '#1F2937' }}>Contacto de privacidad:</p>
          <p style={{ color: '#4B5563' }}>
            Correo: <a href="mailto:privacidad@narra.mx" className="font-semibold" style={{ color: '#4DB3A8' }}>privacidad@narra.mx</a>
          </p>
        </div>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>2. Datos personales que podemos recabar</h2>
        <p style={{ color: '#4B5563' }}>
          Dependiendo de cómo interactúe con Narra, podemos obtener las siguientes categorías de datos:
        </p>
        <ol className="list-decimal ml-6 space-y-3" style={{ color: '#4B5563' }}>
          <li><strong>Datos de identificación y contacto:</strong> nombre, apellidos, correo electrónico, país o ciudad de residencia, idioma preferido.</li>
          <li><strong>Datos de cuenta y autenticación:</strong> usuario, contraseña (en forma cifrada), identificadores internos.</li>
          <li><strong>Datos de pago y facturación:</strong> método de pago, referencia de transacción, RFC (si aplica en México), razón social, país de facturación.</li>
          <li><strong>Datos de uso del servicio:</strong> historias creadas, textos ingresados, archivos o imágenes que usted suba, configuración de privacidad de esas historias, tiempo de uso, clics, interacciones.</li>
          <li><strong>Datos técnicos:</strong> dirección IP, tipo de navegador, sistema operativo, zona horaria, identificadores de dispositivo, cookies y tecnologías similares.</li>
          <li><strong>Datos generados por IA / asistencia:</strong> cuando use funciones de ayuda para redactar, mejorar o estructurar historias, el contenido puede procesarse para prestar el servicio, mejorar modelos y prevenir abuso.</li>
          <li><strong>Datos de soporte o atención:</strong> mensajes que envíe a nuestros canales de ayuda.</li>
        </ol>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          No solicitamos datos sensibles de manera habitual (salud, ideología, orientación sexual, afiliaciones sindicales). Si usted los incluye voluntariamente en sus historias, entiende que los está haciendo parte de su contenido y que deben manejarse con particular cuidado. Puede cambiar la visibilidad de sus historias dentro de la plataforma.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>3. Finalidades del tratamiento</h2>
        <p style={{ color: '#4B5563' }}>
          Tratamos sus datos personales para las siguientes <strong>finalidades principales</strong> (sin las cuales no podríamos prestarle el servicio):
        </p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Crear y administrar su cuenta en Narra.</strong></li>
          <li><strong>Prestarle el servicio de creación, organización y publicación de historias personales y familiares.</strong></li>
          <li><strong>Procesar el pago único correspondiente a su acceso al servicio.</strong></li>
          <li><strong>Mantener la seguridad de la cuenta y de la plataforma.</strong></li>
          <li><strong>Brindar soporte y atención al usuario.</strong></li>
        </ol>
        <p className="mt-6" style={{ color: '#4B5563' }}>
          Además, podemos usar sus datos para <strong>finalidades secundarias u opcionales</strong>, por ejemplo:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Envío de comunicaciones informativas sobre nuevas funciones, mejoras o cambios en Narra.</li>
          <li>Mercadotecnia propia y análisis estadístico de uso (de forma agregada o seudonimizada).</li>
          <li>Mejora de la experiencia de usuario y personalización del contenido.</li>
        </ul>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          Usted puede <strong>oponerse a las finalidades secundarias</strong> en cualquier momento escribiendo a <a href="mailto:privacidad@narra.mx" className="font-semibold" style={{ color: '#4DB3A8' }}>privacidad@narra.mx</a>. Su negativa no afectará las finalidades principales.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>4. Base de legitimación</h2>
        <p style={{ color: '#4B5563' }}>Dependiendo de su país, tratamos sus datos con una o varias de estas bases:</p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Ejecución de un contrato:</strong> cuando se registra y paga por el servicio.</li>
          <li><strong>Cumplimiento de obligaciones legales:</strong> facturación, contabilidad, atención de requerimientos de autoridad.</li>
          <li><strong>Interés legítimo:</strong> seguridad de la plataforma, prevención de fraude, mejora del servicio.</li>
          <li><strong>Consentimiento:</strong> cuando la ley lo requiere (por ejemplo, para comunicaciones comerciales o ciertas cookies).</li>
        </ul>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          En la Unión Europea, cuando el tratamiento se base en su consentimiento, usted puede retirarlo en cualquier momento, sin que ello afecte la licitud del tratamiento previo.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>5. Transferencias y destinatarios de datos</h2>
        <p style={{ color: '#4B5563' }}>Podemos compartir datos con:</p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Proveedores de servicios tecnológicos</strong> (hosting, almacenamiento en la nube, analítica, pasarelas de pago) que actúan siguiendo instrucciones de Narra y con medidas de seguridad adecuadas.</li>
          <li><strong>Proveedores de pago y facturación</strong>, para procesar el pago único que le habilita el uso del servicio.</li>
          <li><strong>Autoridades competentes</strong>, cuando exista una obligación legal o una orden válida.</li>
          <li><strong>Socios comerciales o filiales</strong> de Narra, únicamente para los fines descritos y siempre bajo acuerdos de confidencialidad.</li>
        </ol>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          Si la transferencia se realiza hacia países con un nivel de protección distinto al de su país (por ejemplo, servidores en EE. UU. o la UE), Narra procurará contar con mecanismos de protección adecuados (cláusulas contractuales estándar, acuerdos de encargado, etc.), especialmente para usuarios de la Unión Europea.
        </p>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          Narra <strong>no vende</strong> datos personales a terceros con fines de explotación comercial ajena a la plataforma.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>6. Conservación de los datos</h2>
        <p style={{ color: '#4B5563' }}>
          Conservaremos sus datos <strong>solo durante el tiempo necesario</strong> para cumplir las finalidades descritas o mientras exista una relación contractual y, posteriormente, durante los plazos de prescripción aplicables (por ejemplo, fiscales o de defensa ante reclamaciones).
        </p>
        <ul className="list-disc ml-6 space-y-2 mt-4" style={{ color: '#4B5563' }}>
          <li>Datos de cuenta: mientras su cuenta esté activa.</li>
          <li>Datos de pago/facturación: por los años que exija la normativa fiscal aplicable.</li>
          <li>Contenido (historias): hasta que usted lo elimine o cierre su cuenta, salvo copia de seguridad por tiempo limitado.</li>
          <li>Logs y datos técnicos: por periodos razonables para seguridad y mejora del servicio.</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>7. Derechos del titular (ARCO, GDPR, otros)</h2>
        <p style={{ color: '#4B5563' }}>Usted puede ejercer, según su país, los siguientes derechos:</p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Acceso:</strong> saber qué datos tenemos de usted.</li>
          <li><strong>Rectificación:</strong> solicitar la corrección de datos inexactos o incompletos.</li>
          <li><strong>Cancelación / Supresión:</strong> pedir que eliminemos sus datos cuando ya no sean necesarios o cuando retire su consentimiento.</li>
          <li><strong>Oposición:</strong> oponerse al tratamiento para ciertas finalidades.</li>
          <li><strong>Limitación del tratamiento:</strong> en la UE, puede pedir que limitemos el tratamiento en determinados casos.</li>
          <li><strong>Portabilidad:</strong> en la UE, puede solicitar que le entreguemos sus datos en un formato estructurado y de uso común.</li>
          <li><strong>No ser objeto de decisiones automatizadas</strong> con efectos jurídicos importantes, salvo las excepciones contempladas por la ley.</li>
        </ul>
        <p className="mt-6" style={{ color: '#4B5563' }}>
          Para ejercerlos, escriba a <a href="mailto:privacidad@narra.mx" className="font-semibold" style={{ color: '#4DB3A8' }}>privacidad@narra.mx</a> indicando:
        </p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Nombre completo</li>
          <li>Derecho que desea ejercer</li>
          <li>Medio de respuesta</li>
          <li>Documentos que acrediten su identidad</li>
        </ol>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          Narra responderá dentro de los plazos legales aplicables (en México, generalmente 20 días para responder y 15 más para hacer efectivo el derecho; en la UE, hasta 1 mes, prorrogable en casos complejos).
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>8. Uso de cookies y tecnologías similares</h2>
        <p style={{ color: '#4B5563' }}>El Sitio puede usar cookies propias y de terceros para:</p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>recordar su sesión,</li>
          <li>medir tráfico y rendimiento,</li>
          <li>mejorar la experiencia de escritura y publicación,</li>
          <li>mostrar contenidos más relevantes.</li>
        </ul>
        <p className="mt-4" style={{ color: '#4B5563' }}>
          Usted puede gestionar las cookies desde su navegador o, cuando esté disponible, desde el banner o panel de configuración del Sitio. Algunas cookies son necesarias para el funcionamiento básico.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>9. Menores de edad</h2>
        <p style={{ color: '#4B5563' }}>
          La plataforma está dirigida a <strong>personas mayores de edad</strong> conforme a la legislación aplicable. No recabamos deliberadamente datos de menores. Si un padre/madre/tutor detecta que un menor ha proporcionado datos, puede escribirnos para solicitar su eliminación.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>10. Seguridad de la información</h2>
        <p style={{ color: '#4B5563' }}>
          Narra aplica medidas administrativas, técnicas y físicas razonables para proteger sus datos contra pérdida, uso indebido, acceso no autorizado, divulgación o alteración. Sin embargo, ningún sistema es 100% seguro. Si detectamos una violación de seguridad que pueda afectarle de forma significativa, lo notificaremos conforme a la normativa aplicable.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>11. Cambios al Aviso de Privacidad</h2>
        <p style={{ color: '#4B5563' }}>
          Podemos actualizar este Aviso de Privacidad para reflejar cambios legales, técnicos o de negocio. Publicaremos la versión actualizada en <strong>https://narra.mx</strong> con la fecha de actualización. Si el cambio es sustancial (por ejemplo, cambio de finalidad, nuevas transferencias), podremos notificarle por correo o dentro de la plataforma.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>12. Relación con los precios y modelo de pago</h2>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Narra puede <strong>modificar los precios del servicio en cualquier momento</strong> para nuevas contrataciones o nuevas versiones del producto.</li>
          <li>El hecho de que haya <strong>un solo pago para usar todo el servicio</strong> no afecta sus derechos de privacidad ni amplía el tratamiento de sus datos más allá de lo necesario para cobrar, facturar, administrar su cuenta y demostrar la operación.</li>
          <li>Cualquier información de pago se tratará bajo estándares de seguridad de la pasarela utilizada (p. ej. PCI DSS, en su caso). Narra no almacena información completa de su tarjeta si la pasarela lo desaconseja.</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>13. Ley aplicable y resolución de controversias</h2>
        <p style={{ color: '#4B5563' }}>
          El tratamiento de datos personales se realizará preferentemente conforme a las leyes de <strong>México</strong>. No obstante:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Si usted reside en un país de la UE, aplicaremos las garantías mínimas del <strong>GDPR</strong>.</li>
          <li>Si su legislación local establece requisitos más protectores, haremos esfuerzos razonables para atenderlos.</li>
          <li>Puede presentar una queja ante la autoridad de protección de datos de su país (por ejemplo, el INAI en México o la autoridad de protección de datos de su Estado miembro en la UE).</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>14. Contacto</h2>
        <p style={{ color: '#4B5563' }}>Para dudas sobre este Aviso o para ejercer derechos:</p>
        <div className="p-6 rounded-2xl mt-4" style={{ background: '#E8F5F4' }}>
          <p className="font-bold mb-2" style={{ color: '#1F2937' }}>Narra</p>
          <p style={{ color: '#4B5563' }}>
            Correo: <a href="mailto:privacidad@narra.mx" className="font-semibold" style={{ color: '#4DB3A8' }}>privacidad@narra.mx</a>
          </p>
        </div>

        <div className="mt-12 pt-8 border-t text-center" style={{ borderColor: '#E8F5F4' }}>
          <p className="font-bold text-lg" style={{ color: '#1F2937' }}>
            Narra — Aviso de Privacidad
          </p>
        </div>
      </div>
    </LegalPageLayout>
  );
};
