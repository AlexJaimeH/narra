import React from 'react';
import { LegalPageLayout } from '../components/LegalPageLayout';

export const TermsPage: React.FC = () => {
  return (
    <LegalPageLayout title="Términos y Condiciones de Uso">
      <div className="prose prose-lg max-w-none">
        <div className="mb-8 pb-6 border-b" style={{ borderColor: '#E8F5F4' }}>
          <p className="text-sm font-semibold mb-1" style={{ color: '#4DB3A8' }}>
            Sitio: https://narra.mx
          </p>
          <p className="text-sm font-semibold mb-1" style={{ color: '#4DB3A8' }}>
            Titular: Narra
          </p>
          <p className="text-sm" style={{ color: '#6B7280' }}>
            Última actualización: 11 de noviembre de 2025
          </p>
        </div>

        <div className="p-6 rounded-2xl mb-8" style={{ background: '#E8F5F4' }}>
          <p className="text-lg leading-relaxed m-0" style={{ color: '#1F2937' }}>
            <strong>IMPORTANTE:</strong> Al acceder, navegar o usar el sitio web <strong>narra.mx</strong> (en adelante, el "Sitio") y/o los servicios, aplicaciones, contenidos o funcionalidades asociados (en conjunto, los "Servicios"), usted declara que ha leído, entendido y aceptado estos <strong>Términos y Condiciones de Uso</strong> (los "Términos"). Si no está de acuerdo con ellos, debe abstenerse de usar el Sitio y los Servicios.
          </p>
        </div>

        <p style={{ color: '#4B5563' }}>
          Estos Términos están diseñados para ser compatibles, en lo posible, con requisitos comunes de <strong>México y Latinoamérica</strong> (incluida la Ley Federal de Protección al Consumidor de México y principios de comercio electrónico), así como con estándares de <strong>EE. UU.</strong> y con obligaciones derivadas de <strong>la Unión Europea (UE), en especial el Reglamento General de Protección de Datos (GDPR) en lo que sea aplicable a usuarios de la UE</strong>. Debido a que la regulación puede variar según su país o estado, algunas disposiciones solo aplicarán si la ley local así lo exige.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>1. Definiciones</h2>
        <ul className="space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Narra</strong>: Persona moral titular del Sitio y los Servicios, con domicilio de contacto indicado en la sección 20.</li>
          <li><strong>Usuario</strong> o <strong>Usted</strong>: Persona física o moral que accede o usa el Sitio y/o los Servicios.</li>
          <li><strong>Servicios</strong>: Funcionalidades puestas a disposición por Narra a través del Sitio, incluidas, de forma enunciativa, no limitativa: creación de historias, publicación de contenido, suscripción, lectura, interacción y demás herramientas digitales.</li>
          <li><strong>Contenido</strong>: Todo texto, imagen, audio, video, material creativo o informativo publicado en el Sitio, ya sea por Narra o por los usuarios.</li>
          <li><strong>Consumidor de la UE</strong>: Usuario cuya residencia habitual esté en un Estado miembro de la Unión Europea.</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>2. Aceptación de los Términos</h2>
        <p style={{ color: '#4B5563' }}>Al usar el Sitio o los Servicios, usted confirma que:</p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Tiene al menos 18 años o la mayoría de edad legal aplicable en su jurisdicción.</li>
          <li>Tiene capacidad legal para obligarse.</li>
          <li>En caso de usar los Servicios en representación de una empresa u organización, cuenta con las facultades suficientes para obligarla frente a Narra.</li>
          <li>Acepta cumplir estos Términos y cualquier política adicional publicada en el Sitio (por ejemplo, <strong>Aviso de Privacidad</strong>, <strong>Política de Cookies</strong>, <strong>Lineamientos de Comunidad</strong>).</li>
        </ol>
        <p style={{ color: '#4B5563' }}>
          Narra puede actualizar estos Términos en cualquier momento. La versión vigente será la publicada en <strong>narra.mx</strong> con la fecha de última actualización. El uso posterior del Sitio implica aceptación de los cambios.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>3. Objeto del Sitio y de los Servicios</h2>
        <p style={{ color: '#4B5563' }}>
          Narra ofrece una plataforma digital orientada a la <strong>creación, organización y difusión de historias personales y familiares</strong>, con posibles funciones de suscripción, publicación estilo blog, apoyo con IA y, eventualmente, productos derivados (p. ej. impresión de historias cuando se cumplan ciertas condiciones que se describan en el Sitio). El alcance concreto de cada funcionalidad puede variar según el plan, la región o el momento.
        </p>
        <p style={{ color: '#4B5563' }}>Narra se reserva el derecho de:</p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Modificar o descontinuar temporal o permanentemente cualquier Servicio.</li>
          <li>Restringir el acceso a ciertas secciones a usuarios registrados o de pago.</li>
          <li>Establecer nuevas condiciones comerciales.</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>4. Registro de cuenta y veracidad de datos</h2>
        <p style={{ color: '#4B5563' }}>Algunas funcionalidades requieren crear una cuenta. Usted se compromete a:</p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Proporcionar datos veraces, completos y actualizados.</li>
          <li>Mantener la confidencialidad de sus credenciales.</li>
          <li>Notificar a Narra de inmediato sobre cualquier uso no autorizado.</li>
          <li>No suplantar a terceros.</li>
        </ul>
        <p style={{ color: '#4B5563' }}>
          Narra puede suspender o cancelar cuentas cuando detecte uso indebido, información falsa o violación de estos Términos.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>5. Condiciones comerciales y suscripciones</h2>
        <p style={{ color: '#4B5563' }}>
          Cuando el Sitio ofrezca planes de pago o suscripciones (por ejemplo, una cuota mensual en pesos mexicanos u otra moneda equivalente):
        </p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Precios y moneda.</strong> Los precios se mostrarán en la moneda indicada en el Sitio y podrán incluir o no impuestos según la jurisdicción.</li>
          <li><strong>Pago recurrente.</strong> Al registrarse en un plan de suscripción, usted autoriza el cargo periódico hasta que cancele conforme al procedimiento publicado en el Sitio.</li>
          <li><strong>Facturación.</strong> Cuando la normativa fiscal lo exija, Narra pondrá a disposición los comprobantes correspondientes.</li>
          <li><strong>Reembolsos.</strong> Salvo que la ley aplicable disponga lo contrario (por ejemplo, ciertos derechos de desistimiento en la UE), las cuotas pagadas no son reembolsables porque se trata de servicios digitales de acceso inmediato.</li>
          <li><strong>Promociones.</strong> Pueden existir promociones o periodos de prueba regulados por términos específicos. En caso de conflicto, prevalecen esos términos específicos.</li>
        </ol>

        <h3 className="text-xl font-bold mt-8 mb-3" style={{ color: '#1F2937' }}>5.1 Usuarios de la Unión Europea</h3>
        <p style={{ color: '#4B5563' }}>
          Si usted es consumidor de la UE y adquiere un servicio digital a distancia, puede tener derecho de desistimiento de 14 días <strong>a menos que</strong>:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>El servicio se haya ejecutado por completo durante ese plazo, y</li>
          <li>Usted haya aceptado expresamente que perdería el derecho de desistimiento al comenzar la ejecución.</li>
        </ul>
        <p style={{ color: '#4B5563' }}>
          Narra podrá habilitar mecanismos claros para ejercer ese derecho cuando aplique.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>6. Uso permitido y prohibido</h2>
        <p style={{ color: '#4B5563' }}>
          Usted se compromete a usar el Sitio y los Servicios únicamente con fines lícitos y conforme a la normativa aplicable. Queda prohibido:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Usar el Sitio para actividades ilegales, difamatorias, fraudulentas, obscenas o que vulneren derechos de terceros.</li>
          <li>Publicar o transmitir contenido que infrinja derechos de autor, marcas, secretos industriales o datos personales de terceros.</li>
          <li>Introducir virus, malware o cualquier código destinado a interrumpir el funcionamiento del Sitio.</li>
          <li>Extraer, hacer scraping, minería masiva de datos o uso automatizado no autorizado.</li>
          <li>Crear cuentas múltiples con fines abusivos.</li>
          <li>Eludir medidas de seguridad.</li>
        </ul>
        <p style={{ color: '#4B5563' }}>
          Narra podrá suspender o dar de baja su cuenta y, en su caso, informar a las autoridades cuando exista sospecha de actividad ilícita.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>7. Contenido generado por el usuario</h2>
        <p style={{ color: '#4B5563' }}>
          Al subir, crear o publicar contenido en el Sitio (texto, fotos, audio, video u otros), usted declara que:
        </p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Tiene los derechos necesarios para usar y publicar ese contenido.</li>
          <li>Ese contenido no vulnera leyes ni derechos de terceros.</li>
          <li>Concede a Narra una <strong>licencia no exclusiva, mundial, gratuita, por el tiempo que la ley permita y sublicenciable</strong> para <strong>alojar, reproducir, adaptar, mostrar y distribuir</strong> ese contenido <strong>solo con el fin de operar, mejorar y mostrar los Servicios</strong> (por ejemplo, mostrar su historia a los destinatarios que usted indique, crear vistas previas, respaldos, o cumplir una orden judicial).</li>
        </ol>
        <p style={{ color: '#4B5563' }}>
          Usted conserva la titularidad de sus derechos de autor sobre su contenido. Narra no reclamará propiedad sobre sus historias. No obstante, si usted hace público su contenido dentro del Sitio, otros usuarios podrán verlo bajo las reglas de la plataforma.
        </p>
        <p style={{ color: '#4B5563' }}>
          Narra podrá remover o bloquear contenido que considere contrario a la ley, a estos Términos o que haya sido objeto de una reclamación de derechos.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>8. Propiedad intelectual de Narra</h2>
        <p style={{ color: '#4B5563' }}>
          El Sitio, su diseño, marcas, logotipos, código, bases de datos, contenidos propios y demás elementos son propiedad de Narra o de sus licenciantes y están protegidos por las leyes de propiedad intelectual y de competencia desleal aplicables en México, EE. UU., la UE y otros países.
        </p>
        <p style={{ color: '#4B5563' }}>
          No se le otorga ninguna licencia o derecho de uso distinto al estrictamente necesario para usar el Sitio. Queda prohibida la reproducción, modificación, distribución o explotación no autorizada.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>9. Protección de datos personales y privacidad</h2>
        <p style={{ color: '#4B5563' }}>
          El tratamiento de datos personales se regirá por el <a href="/privacidad" className="font-semibold" style={{ color: '#4DB3A8' }}>Aviso de Privacidad</a> de Narra, que forma parte integrante de estos Términos. Ese aviso estará alineado, en la medida de lo posible, con:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>La legislación mexicana aplicable, incluyendo la Ley Federal de Protección de Datos Personales en Posesión de los Particulares.</li>
          <li>El Reglamento General de Protección de Datos (GDPR) para usuarios ubicados en la UE.</li>
          <li>Estándares latinoamericanos y de EE. UU. en materia de privacidad cuando resulten aplicables.</li>
        </ul>
        <p style={{ color: '#4B5563' }}>
          Dependiendo de su país, usted podrá ejercer derechos de acceso, rectificación, cancelación, oposición, portabilidad o limitación del tratamiento mediante los canales indicados en el Aviso de Privacidad.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>10. Cookies y tecnologías similares</h2>
        <p style={{ color: '#4B5563' }}>
          El Sitio puede usar cookies y tecnologías análogas para mejorar la experiencia del usuario, analizar el rendimiento y ofrecer funcionalidades. El detalle de estas tecnologías y la forma de gestionarlas se describirá en la <strong>Política de Cookies</strong> del Sitio.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>11. Enlaces a terceros</h2>
        <p style={{ color: '#4B5563' }}>
          El Sitio puede contener enlaces a sitios, servicios o contenidos de terceros. Narra <strong>no controla ni responde</strong> por dichos sitios ni por sus políticas. El acceso a ellos será bajo su propio riesgo y conforme a los términos establecidos por esos terceros.
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>12. Limitación de responsabilidad</h2>
        <p style={{ color: '#4B5563' }}>En la medida máxima permitida por la ley aplicable:</p>
        <ol className="list-decimal ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li><strong>Narra no garantiza</strong> que el Sitio será ininterrumpido, libre de errores o seguro.</li>
          <li>Los Servicios se proporcionan <strong>"tal cual" y "según disponibilidad"</strong>.</li>
          <li>Narra no será responsable de daños indirectos, incidentales, especiales, punitivos o consecuenciales, ni de pérdida de datos, lucro cesante o daño moral derivados del uso o imposibilidad de uso del Sitio.</li>
          <li>La responsabilidad total de Narra por cualquier reclamación relacionada con los Servicios se limitará, como máximo, al monto efectivamente pagado por usted durante los 3 (tres) meses anteriores al hecho que originó la reclamación, salvo que la ley disponga un mínimo distinto.</li>
        </ol>
        <p style={{ color: '#4B5563' }}>
          Esta cláusula no excluye responsabilidades que no puedan excluirse conforme a la ley de su país (por ejemplo, ciertos derechos irrenunciables de consumidores en la UE o en México).
        </p>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>13. Indemnización</h2>
        <p style={{ color: '#4B5563' }}>
          Usted se obliga a indemnizar y sacar en paz y a salvo a Narra, sus directivos, socios, empleados y proveedores frente a cualquier reclamación, demanda, sanción o daño que se derive de:
        </p>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Su uso del Sitio contrario a estos Términos,</li>
          <li>La violación de derechos de terceros,</li>
          <li>El contenido que haya publicado.</li>
        </ul>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>20. Contacto</h2>
        <p style={{ color: '#4B5563' }}>
          Para cualquier duda, queja o ejercicio de derechos, puede contactar a:
        </p>
        <div className="p-6 rounded-2xl mt-4" style={{ background: '#E8F5F4' }}>
          <p className="font-bold mb-2" style={{ color: '#1F2937' }}>Narra</p>
          <p style={{ color: '#4B5563' }}>
            Correo electrónico: <a href="mailto:contacto@narra.mx" className="font-semibold" style={{ color: '#4DB3A8' }}>contacto@narra.mx</a>
          </p>
        </div>

        <h2 className="text-2xl font-bold mt-12 mb-4" style={{ color: '#1F2937' }}>21. Disposiciones finales</h2>
        <ul className="list-disc ml-6 space-y-2" style={{ color: '#4B5563' }}>
          <li>Si alguna cláusula se declara nula o inaplicable, el resto de los Términos seguirá vigente.</li>
          <li>La falta de exigencia de una obligación no implica renuncia.</li>
          <li>Estos Términos constituyen el acuerdo íntegro entre usted y Narra respecto del uso del Sitio.</li>
        </ul>

        <div className="mt-12 pt-8 border-t text-center" style={{ borderColor: '#E8F5F4' }}>
          <p className="font-bold text-lg" style={{ color: '#1F2937' }}>
            Narra — Todos los derechos reservados.
          </p>
        </div>
      </div>
    </LegalPageLayout>
  );
};
